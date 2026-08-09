require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:signup`
    #
    # The way somebody who is not the first user gets an account.
    #
    # Rails 8's `generate authentication` writes a session and a password reset
    # and **no registration**: it assumes the users arrive from somewhere else.
    # Hobo 2 had one -- `/users/signup`, a `create :signup` step of the user's
    # lifecycle, with its link in the bar -- and Hobo 3 lost it without noticing,
    # because the front page covers the *first* user and nobody ever needed a
    # second one in a test.
    #
    # It is a generator and not something the gem does by itself for the reason
    # everything else here is: an application that does not want people signing
    # up should not have the route at all, and taking a route away is easier to
    # be sure about than turning a flag off.
    class SignupGenerator < Rails::Generators::Base

      source_root File.expand_path("templates", __dir__)

      def create_controller
        template "registrations_controller.rb.erb", "app/controllers/registrations_controller.rb"
      end

      def add_the_routes
        route %(get "/signup" => "registrations#new", as: :signup)
        route %(post "/signup" => "registrations#create", as: :create_signup)
      end

      def say_what_happened
        say [
          "",
          "Signup is at /signup, and the bar offers it to anybody who is not",
          "logged in. Take the routes away and both disappear.",
          "",
        ].join("\n"), :green
      end

    end

  end
end
