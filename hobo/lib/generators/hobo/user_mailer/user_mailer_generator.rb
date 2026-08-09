require "rails/generators"
require "generators/hobo/user_options"

module Hobo
  module Generators

    # `rails generate hobo:user_mailer [name] [--activation-email] [--invite-only]`
    #
    # The mails an account needs before it exists: the one that activates it and
    # the one that invites somebody. Both carry a one-use key from the model's
    # lifecycle (piece 5).
    #
    # Not the password reset: **Rails 8 writes that one** (`PasswordsMailer`), and
    # it is the half of this that Hobo no longer has to carry.
    class UserMailerGenerator < Rails::Generators::Base

      include UserOptions

      source_root File.expand_path("templates", __dir__)

      argument :name, :type => :string, :default => "User",
               :desc => "El modelo de las personas (por defecto: User)"

      def create_mailer
        return say("Sin --activation-email ni --invite-only no hay correo que escribir.", :yellow) unless
          activation_email? || invite_only?

        template "user_mailer.rb.erb", "app/mailers/user_mailer.rb"
        template "activation.text.erb", "app/views/user_mailer/activation.text.erb" if activation_email?
        template "invitation.text.erb", "app/views/user_mailer/invitation.text.erb" if invite_only?
      end

    end

  end
end
