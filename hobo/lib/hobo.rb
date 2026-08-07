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

    def subsites
      # Any directory inside app/controllers defines a subsite
      app_dirs = ["#{Rails.root}/app"] + Hobo.engines.map { |e| "#{e}/app" }
      @subsites ||= app_dirs.map do |app|
                      Dir["#{app}/controllers/*"].map do |f|
                        File.basename(f) if File.directory?(f)
                      end.compact
                    end.flatten
    end

  end

  self.engines = []
  self.stable_cache = nil

end

require 'hobo/model'
require 'hobo/engine'





