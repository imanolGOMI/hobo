module Hobo
  module Generators

    # The two questions every generator of the user family asks, and the answers
    # they hand each other.
    #
    # Hobo 2 had these as `classy_module` mixins (`invite_only.rb`,
    # `activation_email.rb`) included into the setup wizard and the user
    # generators. A `Concern` does the same thing without the DSL, and Thor's
    # `class_option` has to run at class level -- which is what `included do`
    # is for.
    module UserOptions

      extend ActiveSupport::Concern

      included do
        # No `:default`: Thor fills defaults in, and then a generator cannot tell
        # "you did not say" from "you said the default" -- which is exactly what
        # the wizard has to know before deciding whether to ask.
        class_option :activation_email, :type => :boolean,
                     :desc => "El alta crea la cuenta inactiva y manda un correo con la clave para activarla"

        class_option :invite_only, :type => :boolean,
                     :desc => "No hay alta publica: un administrador invita, y el invitado elige su contrasena"
      end

      private

      def activation_email? = options[:activation_email]
      def invite_only? = options[:invite_only]

      # The model the accounts live in. Rails 8's authentication generator calls
      # it `User`; Hobo 2 asked, because an application may call it `Account`.
      def user_model = (respond_to?(:name, true) && name.presence || "User").camelize

      def user_file = "app/models/#{user_model.underscore}.rb"

      def user_exists?
        File.exist?(File.join(destination_root, user_file))
      end

      def complain_about_the_missing_model
        say "No hay #{user_file}: corre antes `bin/rails generate authentication`.", :red
      end

    end

  end
end
