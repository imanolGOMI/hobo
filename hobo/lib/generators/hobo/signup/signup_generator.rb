require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:signup [--activation-email]`
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
    # `--activation-email` is one of the questions the old setup wizard asked,
    # and it is the same answer it always was: the account is created inactive
    # and a mail carries a one-use key that turns it on. The mechanism is the
    # lifecycle of piece 5, which is why this generator writes a `lifecycle`
    # block into the user model instead of a pile of columns and callbacks.
    #
    # It is a generator and not something the gem does by itself for the reason
    # everything else here is: an application that does not want people signing
    # up should not have the route at all, and taking a route away is easier to
    # be sure about than turning a flag off.
    class SignupGenerator < Rails::Generators::Base

      source_root File.expand_path("templates", __dir__)

      class_option :activation_email, :type => :boolean, :default => false,
                   :desc => "El alta crea la cuenta inactiva y manda un correo con la clave para activarla"

      def create_controller
        template "registrations_controller.rb.erb", "app/controllers/registrations_controller.rb"
      end

      def add_the_routes
        route %(get "/signup" => "registrations#new", as: :signup)
        route %(post "/signup" => "registrations#create", as: :create_signup)
        route %(get "/activate/:id" => "registrations#activate", as: :activate) if activation_email?
      end

      def create_mailer
        return unless activation_email?
        template "user_mailer.rb.erb", "app/mailers/user_mailer.rb"
        template "activation.text.erb", "app/views/user_mailer/activation.text.erb"
      end

      # The lifecycle goes **in the model**, because that is where the rules of a
      # user belong: who may sign up, what a signup asks for, what state it
      # leaves the account in, and who may turn it on.
      def teach_the_user_model
        return unless activation_email?

        user = "app/models/user.rb"
        unless File.exist?(File.join(destination_root, user))
          say "No hay app/models/user.rb: corre antes `bin/rails generate authentication`.", :red
          return
        end

        # `indent`: `inject_into_class` puts the text in as it comes, and a
        # model with everything flush against the margin reads like a mistake.
        inject_into_class user, "User", indent(<<~'RUBY', 2)
          include Hobo::Model

          # Sign up, and stay inactive until the key in the mail comes back.
          lifecycle do
            state :inactive, :default => true
            state :active

            create :signup, :available_to => :all,
                   :params => [:email_address, :password, :password_confirmation],
                   :become => :inactive, :new_key => true do
              UserMailer.activation(self, lifecycle.key).deliver_now
              # Development has nowhere to send mail, and an account nobody can
              # activate is hard to debug. The link is in the log.
              Rails.logger.info("ACTIVATION #{Rails.application.routes.url_helpers.activate_path(self, :key => lifecycle.key)}")
            end

            transition :activate, { :inactive => :active }, :available_to => :key_holder
          end

          # An account that has not been activated does not get in. Here rather
          # than in the sessions controller, so it holds wherever the
          # application authenticates.
          def self.authenticate_by(...)
            user = super
            user if user.nil? || user.state.to_s == "active"
          end

          # --- Permissions ---
          #
          # Creating a user directly is for the first one only; everybody else
          # arrives through the lifecycle, which is the authority for its own
          # step.
          def create_permitted?  = self.class.count.zero?
          def update_permitted?  = acting_user == self
          def destroy_permitted? = false
          def view_permitted?(_field) = true
        RUBY
      end

      def remind_about_the_migration
        return unless activation_email?
        say [
          "",
          "El lifecycle anade dos columnas al usuario. Para crearlas:",
          "",
          "  bin/rails generate hobo:migration",
          "",
        ].join("\n"), :green
      end

      def say_what_happened
        say [
          "",
          "Signup is at /signup, and the bar offers it to anybody who is not",
          "logged in. Take the routes away and both disappear.",
          "",
        ].join("\n"), :green
      end

      private

      def activation_email? = options[:activation_email]

    end

  end
end
