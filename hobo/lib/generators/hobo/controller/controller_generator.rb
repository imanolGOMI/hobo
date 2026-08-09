require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:controller <model> [--subsite=admin]`
    #
    # The controller half of a resource: the seven usual actions, each one
    # asking the model whether this person may. For a model that already exists
    # -- one Rails generated, or one you wrote by hand and have just taught
    # `include Hobo::Model`.
    #
    # `hobo:resource` calls this one, so there is a single template for the
    # controller Hobo writes and no chance of two of them drifting apart.
    class ControllerGenerator < Rails::Generators::NamedBase

      source_root File.expand_path("templates", __dir__)

      class_option :subsite, :type => :string, :desc => "Ponlo en un subsitio"

      def create_controller
        template "controller.rb.erb",
                 File.join("app/controllers", subsite_path, "#{file_name.pluralize}_controller.rb")
      end

      private

      def subsite_path = options[:subsite].to_s

      def controller_class_name
        [options[:subsite]&.camelize, "#{class_name.pluralize}Controller"].compact.join("::")
      end

    end

  end
end
