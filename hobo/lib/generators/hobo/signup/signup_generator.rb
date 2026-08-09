require "rails/generators"
require "generators/hobo/user_options"

module Hobo
  module Generators

    # `rails generate hobo:signup [--activation-email] [--invite-only]`
    #
    # A shorter name for `hobo:user_resource`, and the one `hobo new` uses,
    # because what an application asks for at the beginning is "let people get
    # accounts" and not "generate a user resource".
    #
    # It is one line on purpose: **two names for one thing is bad, two
    # implementations of one thing is worse.** Hobo 2 called this family
    # `user_resource`, and that name still works.
    class SignupGenerator < Rails::Generators::Base

      include UserOptions

      def generate_the_user_resource
        invoke "hobo:user_resource", ["User"], options
      end

    end

  end
end
