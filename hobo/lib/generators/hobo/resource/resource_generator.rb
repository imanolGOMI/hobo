require "rails/generators"
require "rails/generators/named_base"

module Hobo
  module Generators

    # `rails generate hobo:resource story title:string body:text`
    #
    # A model with `fields do`, a controller with `auto_actions`, and nothing
    # else. No views -- those are derived. No line in config/routes.rb --
    # `hobo_routes` finds the controller on its own.
    #
    # It is deliberately small. The old generator wrote a model, a controller,
    # four view files and a routes line; three of those are now things Hobo
    # works out, and a generator that writes what can be derived is a generator
    # somebody has to keep in step with it for ever.
    class ResourceGenerator < Rails::Generators::NamedBase

      source_root File.expand_path("templates", __dir__)

      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"

      class_option :subsite, :type => :string, :desc => "Put the controller in a subsite"

      def create_model
        template "model.rb.erb", File.join("app/models", subsite_path, "#{file_name}.rb")
      end

      def create_controller
        template "controller.rb.erb",
                 File.join("app/controllers", subsite_path, "#{file_name.pluralize}_controller.rb")
      end

      def tell_about_the_migration
        say "Ahora: bin/rails generate hobo:migration", :green
      end

      private

      def subsite_path = options[:subsite].to_s

      def controller_class_name
        [options[:subsite]&.camelize, "#{class_name.pluralize}Controller"].compact.join("::")
      end

      def field_declarations
        attributes.map { |a| "    #{a.name} :#{a.type}" }.join("\n")
      end

    end

  end
end
