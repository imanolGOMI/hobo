require 'hobo'
require 'rails'
require 'rails/generators'


module Hobo
  class Engine < Rails::Engine

    ActiveSupport.on_load(:before_configuration) do
      h = config.hobo = ActiveSupport::OrderedOptions.new
      h.app_name = self.class.name.split('::').first.underscore.titleize
      h.developer_features = Rails.env.in?(["development", "test"])
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
      require 'hobo/extensions/action_view/tag_helper'
      require 'hobo/extensions/action_view/translation_helper'
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
