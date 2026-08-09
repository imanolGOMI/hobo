require 'hobo'
require 'rails'
require 'rails/generators'


module Hobo

  # **One gem, one engine** (decision 11).
  #
  # There used to be three -- `Hobo::Engine`, `HoboRapid::Engine` and
  # `HoboBootstrap::Engine` -- one per gem, each rooted at its own directory.
  # Merging the gems gave the three of them the *same* root, and a Rails engine
  # draws `config/routes.rb` relative to its root: the file was drawn three
  # times and the application died on boot with "Invalid route name, already in
  # use: 'dryml_support'".
  #
  # So the initializers of the other two live here now. What they do has not
  # changed; where they live has.
  class Engine < Rails::Engine

    # `bin/rails hobo:tags` is in lib/tasks/hobo_tags.rake and needs no line
    # here: a Rails engine loads `lib/tasks/**/*.rake` by itself. Saying it
    # again with `rake_tasks { load ... }` loads the file twice, and rake adds
    # the second body to the same task instead of replacing it -- so the task
    # ran twice and printed the whole catalogue twice.

    # Was HoboRapid::Engine: the Stimulus half of the catalogue, handed to the
    # application. An engine's `app/javascript` is on nobody's path and its pins
    # are in nobody's import map unless it says so -- and until it did, none of
    # the ported controllers ran in any application.
    initializer "hobo.importmap", :before => "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    # The theme, and **only if the application wants it**.
    #
    # It used to be `require 'hobo_bootstrap'` at the bottom of hobo.rb, which
    # is to say: always, before an application had said anything. With the theme
    # loaded, `<page>` paints a whole document -- `<html>`, the navbar, the
    # stylesheets -- and the controller skips the application's layout, because
    # a page inside a layout that is also a page gives two of everything.
    #
    # So an application that already has a design had no way in. Now it says so:
    #
    #     config.hobo.theme = false
    #
    # and the derived pages come out as **the body alone**, which the
    # application's own layout then wraps. Nothing else changes: the derivation,
    # the forms, the permissions and the rest of the catalogue are the same.
    # `hobo new` asks the question and writes the line.
    # `config.hobo.theme` -- `:clean` (the default), `:bootstrap`, or `false`.
    #
    # A theme is a table of class names and a stylesheet (HoboRapid::Theme), and
    # `<page>` belongs to the catalogue. Which is what makes a second theme
    # possible: until now `<page>` lived *inside* the Bootstrap theme, so there
    # was one theme and no way to have another.
    #
    # `false` loads no `<page>` at all: then `in_page` paints the body alone and
    # the application's own layout wraps it -- semantic class names and not one
    # stylesheet of ours. That is the way in for an application that already has
    # a design.
    initializer "hobo.theme", :before => "hobo.theme_assets" do |app|
      theme = app.config.hobo.theme
      theme = :clean if theme == true
      next unless theme

      require "hobo_rapid/tags/page"
      case theme.to_sym
      when :bootstrap then require "hobo_bootstrap"
      when :clean     then require "hobo_clean"
      else raise ArgumentError, "config.hobo.theme: :clean, :bootstrap o false (era #{theme.inspect})"
      end
    end

    # Was HoboBootstrap::Engine: the theme's stylesheets, served from the gem so
    # an application does not have to copy anything to look like something.
    initializer "hobo.theme_assets" do |app|
      next unless app.config.respond_to?(:assets)
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      # Whatever the theme said it wears, and nothing else.
      app.config.assets.precompile += HoboRapid::Theme.stylesheets.map { |s| "#{s}.css" }
    end

    # Was HoboRapid::Engine: the pages of every model, derived on boot and on
    # every reload. Declaring the model is the ask; an application should not
    # have to say it twice.
    initializer "hobo.derive" do |app|
      app.config.to_prepare do
        next unless defined?(Hobo::Model)
        Hobo::Model.all_models.each { |model| HoboRapid::Derivation.derive(model) }
      end
    end

    ActiveSupport.on_load(:before_configuration) do
      h = config.hobo = ActiveSupport::OrderedOptions.new
      h.app_name = self.class.name.split('::').first.underscore.titleize
      h.developer_features = Rails.env.in?(["development", "test"])
      # The theme is a question, and this is its default answer: Hobo's own,
      # which depends on nothing. `:bootstrap` for Bootstrap 5, `false` for the
      # body of each page and your own layout.
      h.theme = :clean
      # The whole site behind the login, or the models deciding page by page.
      # `hobo new --private` writes the line that turns this on.
      h.private_site = false
      h.rapid_generators_path = Pathname.new File.expand_path('lib/hobo/rapid/generators', Hobo.root)
      h.auto_taglibs_path = Pathname.new File.expand_path('app/views/taglibs/auto', Rails.root)
      h.read_only_file_system = !!ENV['HEROKU_TYPE']
      h.show_translation_keys = false
      h.dryml_only_templates = false
      h.stable_cache_store = nil
    end

    ActiveSupport.on_load(:action_controller) do
      require 'hobo/controller'
      # An application's own controllers say `include Hobo::Controller::Model`,
      # and Zeitwerk loads them without asking anybody first.
      require 'hobo/controller/model'
      require 'hobo/extensions/action_controller/hobo_methods'
    end

    # This was hooked on :action_controller, which meant it ran whenever a
    # controller loaded -- and its first line is `ActionMailer::Base.send
    # :include`, so it blew up wherever ActionMailer had not been loaded too.
    ActiveSupport.on_load(:action_mailer) do
      require 'hobo/extensions/action_mailer/helper'
    end

    ActiveSupport.on_load(:active_record) do
      require 'hobo/extensions/active_record/associations/association'
      require 'hobo/extensions/active_record/associations/collection'
      require 'hobo/extensions/active_record/associations/proxy'
      require 'hobo/extensions/active_record/associations/reflection'
      require 'hobo/extensions/active_record/hobo_methods'
      require 'hobo/extensions/active_record/permissions'
      require 'hobo/extensions/active_record/relation_with_origin'
      require 'hobo/extensions/active_model/name'
      require 'hobo/extensions/active_model/translation'
      require 'hobo/extensions/active_support/cache/file_store'
      # added legacy namespace for backward compatibility
      # TODO: remove the following line if Hobo::VERSION > 1.3.x
      Hobo::ViewHints = Hobo::Model::ViewHints
    end

    ActiveSupport.on_load(:action_view) do
      # Nothing left to load here, and that is the point.
      #
      # There were three. `action_view/tag_helper` reopened `tag` with the 2008
      # signature and broke every helper written since Rails 5.1 (importmap's
      # among them). `action_view/translation_helper` reopened **`translate`**
      # with the 2008 signature -- `translate(key, options = {})` -- and passed
      # that hash to `I18n.translate` positionally, which today is an
      # ArgumentError: so `t("anything")` in any view of the application died.
      # It was there for DRYML's `<t>` tag, and the DRYML compiler is gone.
      #
      # Both were invisible from inside Hobo: a generated Hobo application has
      # no views of its own to call `t` from. It took installing the gem into
      # somebody else's application to see them.
      #
      # There used to be a third one here, `action_view/tag_helper`, which
      # reopened ActionView's `tag` to close elements the XHTML way. It was for
      # the old DRYML compiler, which is gone, and it kept the 2008 signature:
      # `tag(name, options, open, escape)`, with the name required. In Rails the
      # name is optional -- `tag` with no arguments is the tag builder, which is
      # how `tag.script` and everything written since Rails 5.1 works. So the
      # patch broke every page that used it, importmap's included, with
      # "wrong number of arguments (given 0, expected 1..4)".
    end

    ActiveSupport.on_load(:before_initialize) do
      require 'hobo/undefined'
      HoboFields.never_wrap(Hobo::Undefined)
      h = config.hobo
      # The auto-taglib generator belongs to the old DRYML compiler, which is no
      # longer loaded (see dryml/lib/dryml.rb). Generating the views is layers 5
      # to 7, on the new runtime; until then an application boots without it
      # rather than not booting at all.
      if defined?(Dryml::DrymlGenerator)
        Dryml::DrymlGenerator.enable([h.rapid_generators_path], h.auto_taglibs_path)
      end
    end

    initializer 'hobo.i18n' do |app|
      require 'hobo/extensions/i18n' if app.config.hobo.show_translation_keys
    end

    # The routes used to be generated into config/hobo_routes.rb at boot and fed
    # to the routes reloader. They are a method an application calls from its own
    # config/routes.rb now -- see hobo/routes_dsl.rb -- so there is no generated
    # file, booting does not need a writable disk, and the application decides
    # where Hobo's routes sit among its own.
    initializer 'hobo.routes' do |app|
      require 'hobo/routes_dsl'
    end

    # Regenerating the auto taglibs on every reload belongs to the old DRYML
    # compiler, which is not loaded any more. Layers 5 to 7 bring this back on
    # the new runtime; until then an application boots without it.
    initializer 'hobo.dryml' do |app|
      next unless defined?(Dryml::DrymlGenerator)
      unless app.config.hobo.read_only_file_system
        app.config.to_prepare { Dryml::DrymlGenerator.run }
      end
    end

    initializer 'hobo.cache' do |app|
      if app.config.hobo.stable_cache_store
        Hobo.stable_cache = ActiveSupport::Cache.lookup_store(app.config.hobo.stable_cache_store)
      else
        Hobo.stable_cache = Rails.cache
      end
    end

    # hobo_field's rich types let you refer to rich type with symbols:
    #     fields do; shout :loud; end.
    # The problem comes if you never use LoudText in your code, rails
    # autoloader will never kick in and autoload
    # app/rich_types/loud_text.rb, so let's preemptively require
    # everything in that directory.
    initializer 'hobo.rich_types' do |app|
      Dir["#{Rails.root}/app/rich_types/*"].each do |file|
        require_dependency file
      end
    end

  end
end
