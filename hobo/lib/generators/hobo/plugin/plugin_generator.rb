require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:plugin <name>`
    #
    # The skeleton of a Hobo plugin, which since decision 22 is **a gem**: an
    # engine, a file of tags, and its assets. Installing one is putting it in a
    # Gemfile and nothing else.
    #
    # Hobo 2's version of this wrote a `vendor/plugins` directory with a taglib
    # of DRYML, a `//= require` line and a railtie whose only job was to exist.
    # What it writes now is what `hobo_timeago/` in this repository is -- the
    # plugin that was written to prove the contract, and the shortest
    # explanation of it.
    class PluginGenerator < Rails::Generators::NamedBase

      source_root File.expand_path("templates", __dir__)

      class_option :author, :type => :string, :default => "",
                   :desc => "Quien lo firma"

      def create_the_gem
        template "gemspec.erb",     "#{plugin_name}/#{plugin_name}.gemspec"
        template "README.md.erb",   "#{plugin_name}/README.md"
        template "rakefile.erb",    "#{plugin_name}/Rakefile"
        create_file "#{plugin_name}/VERSION", "0.1.0\n"
      end

      def create_the_code
        template "lib.rb.erb",    "#{plugin_name}/lib/#{plugin_name}.rb"
        template "engine.rb.erb", "#{plugin_name}/lib/#{plugin_name}/engine.rb"
        template "tags.rb.erb",   "#{plugin_name}/lib/#{plugin_name}/tags.rb"
      end

      def create_the_assets
        template "importmap.rb.erb",  "#{plugin_name}/config/importmap.rb"
        template "controller.js.erb", "#{plugin_name}/app/javascript/controllers/#{plugin_name}_controller.js"
        template "stylesheet.css.erb", "#{plugin_name}/app/assets/stylesheets/#{plugin_name}.css"
      end

      def create_the_test
        template "test.rb.erb", "#{plugin_name}/test/#{plugin_name}_test.rb"
      end

      def say_what_happened
        say [
          "",
          "El plugin esta en #{plugin_name}/. Para usarlo desde una aplicacion:",
          "",
          %(  gem "#{plugin_name}", :path => "../#{plugin_name}"),
          "",
          "Sus tags se registran al cargarse la gema. Para ver quien define que:",
          "",
          "  bin/rails hobo:tags",
          "",
        ].join("\n"), :green
      end

      private

      def plugin_name = file_name.underscore

      def module_name = plugin_name.camelize

      def author = options[:author].presence || "Tu nombre"

    end

  end
end
