require 'hobo_support'
require 'hobo_fields'
# The tag runtime of layer 3, not the old DRYML compiler. The compiler is still
# in the dryml gem, but only as the front end of the template updater, and it
# needs erubis, which has been dead since 2011.
#
# Seven call sites in the controller and generator layers still name Dryml
# (Dryml.page, .get, .empty, .precompile, Dryml::DrymlGenerator). They belong to
# layers 5 to 7 and will fail loudly when reached, which is what we want.
require 'rapid'
# Ransack answers what the automatic scopes of piece 6 used to: see
# Hobo::Model.ransackable_attributes and hobo_completions.
require 'ransack'
begin
  gem 'hobo_will_paginate'
rescue Gem::LoadError => e
  puts "WARNING: unable to activate hobo_will_paginate.   Please add gem \"hobo_will_paginate\" to your Gemfile." if File.exist?("app/views/taglibs/application.dryml")
  # don't print warning if setup not complete
end
require 'hobo/extensions/enumerable'

# Until Rails 7 this gem leaned on the classic autoloader for its *own*
# internals: `ActiveSupport::Dependencies.autoload_paths` pointed at this
# directory, and a reference to Hobo::Model loaded hobo/model.rb. That
# autoloader is gone -- autoload_paths survives only as a list Zeitwerk reads --
# so lib/ says out loud what it needs, which is what a gem should do anyway and
# makes the load order of the patches visible.

module Hobo

  VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).strip
  @@root = Pathname.new File.expand_path('../..', __FILE__)
  def self.root; @@root; end

  class Error < RuntimeError; end
  class PermissionDeniedError < RuntimeError; end
  class UndefinedAccessError < RuntimeError; end
  class I18nError < RuntimeError; end

  # Empty class to represent the boolean type.
  class Boolean; end
  class RawJs < String; end

  class << self

    attr_accessor :engines, :stable_cache

    # Los temas que hay puestos.
    #
    # Un tema es **una gema**: al cargarse se apunta aqui, y `config.hobo.theme`
    # solo dice cual de los apuntados se usa. Hobo no conoce ninguno por su
    # nombre -- salvo `clean`, que es el suyo y viene dentro, para que una
    # aplicacion recien hecha pinte algo sin instalar nada.
    #
    #   Hobo.theme(:bootstrap) { |subsite| HoboBootstrap.dress(subsite) }
    def themes
      @themes ||= {}
    end

    def theme(name, &block)
      themes[name.to_sym] = block
    end

    # Lo que se le dice a quien trae un modelo de Hobo 2 con `attr_accessible`.
    #
    # Una vez por modelo, con el fichero delante, y diciendo **qué cambia**: no
    # que la línea sobra, sino que la superficie de lo asignable ya no es esa.
    # Un aviso que solo dijera «esto está obsoleto» se ignora; uno que dice
    # dónde mirar, no.
    def warn_about_mass_assignment(model, method, names)
      @mass_assignment_warned ||= {}
      key = "#{model.name}##{method}"
      return if @mass_assignment_warned[key]

      @mass_assignment_warned[key] = true
      file = "app/models/#{model.name.underscore}.rb"
      campos = names.reject { |n| n.is_a?(Hash) }.map(&:to_s).join(", ")

      message = [
        "",
        "AVISO  #{model.name}: `#{method}` ya no hace nada.",
        "       Decia que columnas se podian asignar en masa (#{campos}).",
        "       En Hobo eso lo dicen los permisos del modelo:",
        "       create_permitted? y update_permitted?.",
        "       Revisa #{file} -- ahora se puede asignar todo lo que el permiso deje.",
        "",
      ].join("\n")

      defined?(Rails) && Rails.logger ? Rails.logger.warn(message) : nil
      warn(message)
    end

    # Y lo que se le dice a quien trae un modelo con Paperclip.
    #
    # Distinto del de `attr_accessible`: aquello no hacía nada desde hace doce
    # años y esto **sí funcionaba ayer**. El aviso tiene que decir que los
    # adjuntos están parados, no que hay una línea obsoleta.
    def warn_about_paperclip(model, attachment)
      @paperclip_warned ||= {}
      key = "#{model.name}##{attachment}"
      return if @paperclip_warned[key]

      @paperclip_warned[key] = true
      message = [
        "",
        "AVISO  #{model.name}: `has_attached_file :#{attachment}` esta parado.",
        "       Paperclip se dejo de mantener en 2018 y su relevo es",
        "       ActiveStorage, que viene dentro de Rails.",
        "       La aplicacion arranca, pero **ese adjunto no funciona**.",
        "       Para convertirlo:  bin/rails generate hobo:update --attachments",
        "",
      ].join("\n")

      defined?(Rails) && Rails.logger ? Rails.logger.warn(message) : nil
      warn(message)
    end

    def raw_js(s)
      RawJs.new(s)
    end

    def find_by_search(query, search_targets=[])
      if search_targets.empty?
       search_targets = Hobo::Model.all_models.select {|m| m.search_columns.any? }
      end

      query_words = ActiveRecord::Base.connection.quote_string(query).split

      search_targets.filter_map do |search_target|
        conditions = []
        parameters = []
        like_operator = ActiveRecord::Base.connection.adapter_name =~ /postg/i ? 'ILIKE' : 'LIKE'
        query_words.each do |word|
          column_queries = search_target.search_columns.map { |column| column == "id" ? "CAST(#{column} AS varchar) #{like_operator} ?" : "#{column} #{like_operator} ?" }
          conditions << "(" + column_queries.join(" or ") + ")"
          parameters.concat(["%#{word}%"] * column_queries.length)
        end
        conditions = conditions.join(" and ")

        results = search_target.where(conditions, *parameters)
        [search_target.name, results] unless results.empty?
      end.to_h
    end

    def simple_has_many_association?(array_or_reflection)
      refl = array_or_reflection.respond_to?(:proxy_association) ? array_or_reflection.proxy_association.reflection : array_or_reflection
      return false unless refl.is_a?(ActiveRecord::Reflection::AssociationReflection)
      refl.macro == :has_many and
        (not refl.through_reflection) and
        (not refl.options[:conditions])
    end

    # A directory inside app/controllers that holds controllers defines a
    # subsite: app/controllers/admin/story_controller.rb is the admin subsite.
    #
    # Two things used to go wrong here. `concerns` is a directory Rails creates
    # in **every** application, for shared modules and not for controllers, so
    # every Hobo application had a phantom `concerns` subsite and the router
    # dutifully wrote `namespace :concerns`. And the result was memoised for the
    # life of the process, so a subsite added while the server was running was
    # never seen. Asking for a directory that holds at least one controller fixes
    # both, and it is a couple of globs.
    NOT_A_SUBSITE = %w[concerns].freeze

    # Whether the whole application is behind the login. It is a question an
    # application answers once, in its configuration, and Hobo's controllers
    # read it when they load.
    def private_site?
      return false unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
      !!Rails.application.config.hobo.private_site
    rescue StandardError
      false
    end

    def subsites
      app_dirs = ["#{Rails.root}/app"] + Hobo.engines.map { |e| "#{e}/app" }
      app_dirs.flat_map do |app|
        Dir["#{app}/controllers/*"].filter_map do |dir|
          name = File.basename(dir)
          next unless File.directory?(dir)
          next if name.in?(NOT_A_SUBSITE)
          next if Dir["#{dir}/*_controller.rb"].empty?
          name
        end
      end.uniq
    end

  end

  self.engines = []
  self.stable_cache = nil

end

require 'hobo/model'
require 'hobo/routes'
require 'hobo/engine'

# The catalogue and the theme, which used to be two more gems (decision 11).
# They come last because they read what is above: the derivation engine asks
# Hobo::Model what a model declared, and the theme paints what the catalogue
# gives it.
#
# The theme ships *in* here (decision 13) so that `hobo new` looks right without
# installing anything else -- but it is **loaded by an initializer, not by this
# line** (see hobo/engine.rb): an application can say `config.hobo.theme = false`
# and get the body only, inside its own layout. Requiring it here made that
# impossible, because a gem is loaded before an application has said anything.
#
# Alternative themes stay separate gems -- that is what the plugin contract is
# for.
require 'hobo_rapid'





