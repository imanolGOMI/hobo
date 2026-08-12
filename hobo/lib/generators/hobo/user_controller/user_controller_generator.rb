require "rails/generators"
require "generators/hobo/user_options"

module Hobo
  module Generators

    # `rails generate hobo:user_controller [name] [--activation-email] [--invite-only]`
    #
    # The controller of the pages that make an account, and its routes.
    #
    # Rails 8 writes the session and the password reset; **it writes no
    # registration at all**, which is the hole this fills. What it writes
    # depends on the answers: a plain signup, a signup that waits for a mail, or
    # an invitation flow with no public signup whatsoever.
    #
    # **The route is the switch.** With `--invite-only` the signup routes are not
    # drawn, so the page does not exist and the bar stops offering it by itself.
    class UserControllerGenerator < Rails::Generators::Base

      include UserOptions

      source_root File.expand_path("templates", __dir__)

      argument :name, :type => :string, :default => "User",
               :desc => "El modelo de las personas (por defecto: User)"

      def create_controller
        template "registrations_controller.rb.erb", "app/controllers/registrations_controller.rb"
      end

      def add_the_routes
        unless invite_only?
          route %(get "/signup" => "registrations#new", as: :signup)
          route %(post "/signup" => "registrations#create", as: :create_signup)
          route %(get "/activate/:id" => "registrations#activate", as: :activate) if activation_email?
        end

        if invite_only?
          route %(get "/invite" => "registrations#invite", as: :invite)
          route %(post "/invite" => "registrations#send_invitation", as: :send_invitation)
          route %(get "/accept/:id" => "registrations#accept", as: :accept)
          route %(post "/accept/:id" => "registrations#take_invitation", as: :take_invitation)
        end
      end

      def say_what_happened
        say [
          "",
          invite_only? ? "Nadie se da de alta aqui: un administrador invita, en /invite."
                       : "El alta esta en /signup, y la barra la ofrece a quien no ha entrado.",
          "Quita las rutas y las paginas desaparecen con ellas.",
          "",
        ].join("\n"), :green
      end

    end

  end
end
