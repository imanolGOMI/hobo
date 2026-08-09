require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:front_page`
    #
    # The front controller: an application with no users offers to create the
    # first one, and once there is one it shows the application. It is the
    # first five minutes of Hobo, and Rails has no equivalent -- its
    # authentication generator gives you a login form and expects the first
    # user to arrive from a console.
    class FrontPageGenerator < Rails::Generators::Base

      source_root File.expand_path("templates", __dir__)

      # Hobo 2 asked "Choose a name for the front controller", and it is still a
      # real choice: an application may call its front page `home`.
      argument :name, :type => :string, :default => "front",
               :desc => "Nombre del controlador de portada (por defecto: front)"

      def create_controller
        template "front_controller.rb.erb", "app/controllers/#{name}_controller.rb"
      end

      def add_the_route
        route %(root to: "#{name}#index")
        route %(post "/first-user" => "#{name}#create_first_user", as: :create_first_user)
      end

      private

      def controller_class_name = "#{name.camelize}Controller"

    end

  end
end
