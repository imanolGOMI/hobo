require "rails/generators"
require "generators/hobo/user_options"

module Hobo
  module Generators

    # `rails generate hobo:user_resource [name] [--activation-email] [--invite-only]`
    #
    # The three at once: the model learns how accounts are made, the mailer
    # writes the letters, the controller serves the pages. It is the name Hobo 2
    # used and it is still the one that describes the whole thing.
    #
    # In Hobo 2 it also generated the user model itself, its views and its
    # login. Rails 8 does that half now (decisión 15) -- `bin/rails generate
    # authentication` -- and this adds what Rails leaves out.
    class UserResourceGenerator < Rails::Generators::Base

      include UserOptions

      argument :name, :type => :string, :default => "User",
               :desc => "El modelo de las personas (por defecto: User)"

      # Always: the model that `bin/rails generate authentication` writes has an
      # address and a password and no **name**, and Hobo shows a record by its
      # name. The columns it is missing turn up in the migration the wizard asks
      # about, which is where columns are supposed to turn up.
      #
      # The lifecycle on top of that is what needs an answer: it calls a mailer,
      # and without one of the two flags nobody generated one.
      def generate_the_model
        invoke "hobo:user_model", [name], options
      end

      def generate_the_mailer
        invoke "hobo:user_mailer", [name], options if activation_email? || invite_only?
      end

      def generate_the_controller
        invoke "hobo:user_controller", [name], options
      end

    end

  end
end
