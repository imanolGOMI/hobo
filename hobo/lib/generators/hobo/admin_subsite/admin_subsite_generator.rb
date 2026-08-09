require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:admin_subsite [name]`
    #
    # A part of the application for administrators, with its own controllers over
    # the same models. It was one of the setup wizard's questions and it is the
    # last big one of them.
    #
    # In Hobo 2 this wrote controllers, a DRYML taglib per subsite, a stylesheet,
    # a JavaScript manifest and a theme installation. Here it writes
    # **controllers**, because that is all a subsite is now: `Hobo.subsites` is
    # "a directory under app/controllers that has a controller in it", the router
    # draws those routes under that prefix, and the pages are the derived ones --
    # the same model seen by somebody else.
    class AdminSubsiteGenerator < Rails::Generators::Base

      source_root File.expand_path("templates", __dir__)

      argument :subsite, :type => :string, :default => "admin",
               :desc => "Nombre del subsitio (por defecto: admin)"

      class_option :theme, :type => :string,
                   :desc => "El tema del subsitio: clean, bootstrap (por defecto: el del sitio)"

      # Hobo 2 asked for the admin subsite's theme separately, and it was a fair
      # question: an administration is a different kind of place. A subsite with
      # no theme of its own wears the site's.
      def choose_a_theme
        return if options[:theme].blank?
        application %(    config.hobo.subsite_themes = { "#{subsite}" => :#{options[:theme]} })
      end

      def create_site_controller
        template "site_controller.rb.erb",
                 File.join("app/controllers", subsite, "#{subsite}_controller.rb")
      end

      # One controller per model that has pages. Which models those are is a
      # question for the application, not for a list written here: they are the
      # ones with a controller of their own already.
      def create_resource_controllers
        models.each do |model|
          @plural_class_name = model
          template "resource_controller.rb.erb",
                   File.join("app/controllers", subsite, "#{model.underscore}_controller.rb")
        end
      end

      # An administrator is a person with a flag, and the flag has to exist. The
      # signup generator writes it when the site is invite-only; here it may not
      # be there yet.
      def ensure_the_administrator_field
        user = "app/models/user.rb"
        path = File.join(destination_root, user)
        return say("No hay app/models/user.rb: corre antes `bin/rails generate authentication`.", :red) unless File.exist?(path)
        return if File.read(path).include?("administrator")

        inject_into_class user, "User", indent(<<~'RUBY', 2)
          include Hobo::Model

          # Who may see the admin subsite. `add_fields` and not `fields do`: the
          # table is Rails', and Hobo only adds this column to it.
          add_fields do
            administrator :boolean, :default => false
          end

          # The first person in owns the application.
          before_create do
            self.administrator = true if self.class.count.zero?
          end

          def create_permitted?  = self.class.count.zero?
          def update_permitted?  = acting_user == self
          def destroy_permitted? = false
          def view_permitted?(_field) = true
        RUBY

        @added_a_field = true
      end

      def say_what_happened
        lines = ["", "El subsitio esta en /#{subsite}, y es para administradores."]
        lines += ["", "Lleva el tema #{options[:theme]}; el resto del sitio, el suyo."] if options[:theme].present?
        if @added_a_field
          lines += ["", "Se le ha anadido el campo `administrator` al usuario. Para crearlo:",
                    "", "  bin/rails generate hobo:migration"]
        end
        lines += ["", "Cada controlador nuevo dentro de app/controllers/#{subsite}/ entra solo:",
                  "un subsitio es una carpeta de controladores, no un registro en ningun sitio.", ""]
        say lines.join("\n"), :green
      end

      private

      attr_reader :plural_class_name

      # The application's own resource controllers, by name: `StoriesController`
      # in app/controllers gives `Stories`.
      # A resource controller is one that **says so**: `include
      # Hobo::Controller::Model`. This used to be a list of names to skip
      # (`front`, `sessions`, `passwords`…), and the day somebody called their
      # front page `portada` the admin subsite got a controller for the front
      # page. Reading the file is both shorter and right.
      def models
        Dir[File.join(destination_root, "app", "controllers", "*_controller.rb")].filter_map do |file|
          next unless File.read(file).include?("Hobo::Controller::Model")
          File.basename(file, "_controller.rb").camelize
        end.sort
      end

    end

  end
end
