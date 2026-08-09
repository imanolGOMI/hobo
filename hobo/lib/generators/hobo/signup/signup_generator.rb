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

      class_option :invite_only, :type => :boolean, :default => false,
                   :desc => "No hay alta publica: un administrador invita, y el invitado elige su contrasena"

      def create_controller
        template "registrations_controller.rb.erb", "app/controllers/registrations_controller.rb"
      end

      # **The route is the switch.** With `--invite-only` there is no signup
      # route at all, so there is nothing to guess at: the page does not exist,
      # and the bar stops offering it by itself, because the tag asks whether
      # the route is there.
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

      def create_mailer
        return unless activation_email? || invite_only?
        template "user_mailer.rb.erb", "app/mailers/user_mailer.rb"
        template "activation.text.erb", "app/views/user_mailer/activation.text.erb" if activation_email?
        template "invitation.text.erb", "app/views/user_mailer/invitation.text.erb" if invite_only?
      end

      # The lifecycle goes **in the model**, because that is where the rules of a
      # user belong: who may sign up, what a signup asks for, what state it
      # leaves the account in, and who may turn it on.
      def teach_the_user_model
        return unless activation_email? || invite_only?

        user = "app/models/user.rb"
        unless File.exist?(File.join(destination_root, user))
          say "No hay app/models/user.rb: corre antes `bin/rails generate authentication`.", :red
          return
        end

        # `indent`: `inject_into_class` puts the text in as it comes, and a
        # model with everything flush against the margin reads like a mistake.
        inject_into_class user, "User", indent(model_lines, 2)
      end

      # What the user model has to say, and **only** what it has to say.
      #
      # No `fields do` block: that would be this model claiming it describes the
      # whole `users` table, and the table is Rails'. `add_fields` says the
      # opposite -- these columns are Hobo's, the rest is not mine to touch --
      # and without it the migration generator offers to drop `email_address`
      # and `password_digest`.
      def model_lines
        lines = ["include Hobo::Model", ""]

        if invite_only?
          lines << "# Who may invite. The first person in is the administrator, which is"
          lines << "# what the front page has been promising all along."
          lines << "add_fields do"
          lines << "  administrator :boolean, :default => false"
          lines << "end"
          lines << ""
          lines << "# An invited account has no password until the person accepts it, and"
          lines << "# Rails' has_secure_password insists on a digest being there. This one"
          lines << "# matches nothing anybody can type."
          lines << "#"
          lines << "# The digest and not `self.password = ...`: **inside a lifecycle step"
          lines << "# only the attributes the step declares get through** -- that is the"
          lines << "# permission layer doing its job -- so assigning the password here is"
          lines << "# quietly dropped and the record fails with \"Password can't be blank\"."
          lines << "#"
          lines << "# And no `:on => :create`: while a lifecycle step is running the"
          lines << "# validation context is the **step's name** (:invite), which is what"
          lines << "# lets a model say `validates :x, :on => :signup`. A callback asking"
          lines << "# for :create never fires there. The state is the guard that matters."
          lines << "before_validation do"
          lines << "  if new_record? && state.to_s == \"invited\" && password_digest.blank?"
          lines << "    self.password_digest = BCrypt::Password.create(SecureRandom.hex(32))"
          lines << "  end"
          lines << "end"
          lines << ""
        end

        # The first person in arrives through the front page, which creates the
        # record **directly** -- there is nobody yet to run a lifecycle step and
        # no mail to answer. So the default state does not apply to them: they
        # are in, and they own the application. Without this the first user was
        # created `inactive` (or `invited`) and could not log in, which is a
        # locked door with the key inside.
        lines << "# The first person in owns the application, and is already in: the front"
        lines << "# page creates them directly, so no lifecycle step ran for them."
        lines << "before_create do"
        lines << "  if self.class.count.zero?"
        lines << "    self.administrator = true" if invite_only?
        lines << "    self.state = \"active\""
        lines << "  end"
        lines << "end"
        lines << ""

        lines.concat(lifecycle_lines)
        lines << ""
        lines.concat(<<~'RUBY'.lines.map(&:chomp))
          # An account that is not active does not get in. Here rather than in the
          # sessions controller, so it holds wherever the application
          # authenticates.
          def self.authenticate_by(...)
            user = super
            user if user.nil? || user.state.to_s == "active"
          end

          # --- Permissions ---
          #
          # Creating a user directly is for the first one only; everybody else
          # arrives through the lifecycle, which is the authority for its own step.
          def create_permitted?  = self.class.count.zero?
          def update_permitted?  = acting_user == self
          def destroy_permitted? = false
          def view_permitted?(_field) = true
        RUBY
        lines.join("\n") + "\n"
      end

      def lifecycle_lines
        if invite_only?
          <<~'RUBY'.lines.map(&:chomp)
            # Nobody signs up: somebody invites you, and you choose a password.
            lifecycle do
              state :invited, :default => true
              state :active

              create :invite, :available_to => "acting_user if acting_user.try(:administrator?)",
                     :params => [:email_address], :become => :invited, :new_key => true do
                UserMailer.invitation(self, lifecycle.key, acting_user).deliver_now
                Rails.logger.info("INVITATION #{Rails.application.routes.url_helpers.accept_path(self, :key => lifecycle.key)}")
              end

              transition :accept_invitation, { :invited => :active }, :available_to => :key_holder,
                         :params => [:password, :password_confirmation]
            end
          RUBY
        else
          <<~'RUBY'.lines.map(&:chomp)
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
          RUBY
        end
      end

      def remind_about_the_migration
        return unless activation_email? || invite_only?
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
          invite_only? ? "Nobody signs up here: an administrator invites, at /invite."
                       : "Signup is at /signup, and the bar offers it to anybody who is not logged in.",
          "Take the routes away and the pages disappear with them.",
          "",
        ].join("\n"), :green
      end

      private

      def activation_email? = options[:activation_email]
      def invite_only? = options[:invite_only]

    end

  end
end
