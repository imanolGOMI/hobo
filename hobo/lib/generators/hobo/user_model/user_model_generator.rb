require "rails/generators"
require "generators/hobo/user_options"

module Hobo
  module Generators

    # `rails generate hobo:user_model [name]`
    #
    # Turns a model into the one people log in as: the lifecycle that says how
    # an account is made, and the permissions that say who may touch it.
    #
    # In Hobo 2 this **wrote** the model, because Hobo owned the user. Rails 8
    # writes it now (`bin/rails generate authentication`) and this adds Hobo's
    # half to whatever is there -- which is why it declares its columns with
    # `add_fields` and not `fields do`: the table is Rails' and Hobo only adds
    # to it (decisión 26).
    class UserModelGenerator < Rails::Generators::Base

      include UserOptions

      argument :name, :type => :string, :default => "User",
               :desc => "El modelo de las personas (por defecto: User)"

      # There is always something to teach it, and it is the person's **name**.
      #
      # `bin/rails generate authentication` writes an address and a password
      # digest, and that is all Rails needs to let somebody in. Hobo shows a
      # record by its `name` field, so a user without one is "User 1" -- in the
      # bar, in every link to them, in every page title -- and the form that
      # asks for the first user asks for an address and a password and never for
      # a name. Hobo 2's user model declared `name :string, :required, :unique`
      # and this is what became of it.
      #
      # The lifecycle on top of that, only when there is one to write: it calls
      # a mailer, and without `--activation-email` or `--invite-only` nobody
      # generated one.
      def teach_the_model
        return complain_about_the_missing_model unless user_exists?

        # Ya es de Hobo, **pero puede faltarle el ciclo de vida**.
        #
        # `hobo new` deja el modelo con `include Hobo::Model` puesto, asi que
        # este generador se daba por hecho y se iba. Consecuencia: en una
        # aplicacion recien creada, `hobo:signup --activation-email` escribia las
        # rutas, el controlador y el mailer, y **el ciclo de vida no llegaba
        # nunca al modelo**. La activacion por correo no se podia anadir a una
        # aplicacion de Hobo: solo a un modelo que no fuera de Hobo todavia.
        #
        # No daba error -- decia «ya es un modelo de Hobo» en amarillo y seguia
        # --, y lo que fallaba despues era la migracion, que no encontraba las
        # columnas `state` y `key_timestamp` de un ciclo de vida que no existe.
        if already_taught?
          return say("#{user_file} ya es un modelo de Hobo.", :yellow) if lifecycle_lines.empty? || lifecycle_written?

          say "#{user_file} ya es un modelo de Hobo: se le anade el ciclo de vida.", :green
          # **Detras del `include`**, y no con `inject_into_class`, que escribe
          # al principio de la clase: el ciclo de vida se declara con un metodo
          # que trae `Hobo::Model`, asi que puesto encima se ejecuta antes de
          # que exista y el modelo no carga -- «undefined method 'lifecycle'».
          #
          # Y una cadena, no un array: `indent` trabaja con texto, y con un
          # array devolvia algo que se escribia sin poner nada.
          return inject_into_file(user_file, indent((["", *lifecycle_lines].join("\n") + "\n"), 2),
                                  :after => /include Hobo::Model\n/)
        end

        # `indent`: `inject_into_class` puts the text in as it comes, and a
        # model with everything flush against the margin reads like a mistake.
        inject_into_class user_file, user_model, indent(model_lines, 2)
      end

      def remind_about_the_migration
        say [
          "",
          "El modelo tiene columnas nuevas. Para crearlas:",
          "",
          "  bin/rails generate hobo:migration",
          "",
        ].join("\n"), :green
      end

      private

      def already_taught?
        File.read(File.join(destination_root, user_file)).include?("include Hobo::Model")
      end

      # Si el ciclo de vida ya esta escrito, para no ponerlo dos veces al
      # repetir el generador.
      def lifecycle_written?
        File.read(File.join(destination_root, user_file)).include?("lifecycle do")
      end

      def model_lines
        lines = ["include Hobo::Model", ""]

        # El nombre, siempre. Ver arriba: sin él una persona es «User 1» en toda
        # la aplicación, y el alta no lo pide porque no existe.
        lines << "# How this person is shown: Hobo names a record by its `name`, and"
        lines << "# Rails' user model has only an address."
        lines << "add_fields do"
        lines << "  name :string, :required"
        lines << "end"
        lines << ""

        unless activation_email? || invite_only?
          # Sin lifecycle, quien decide quién puede hacer qué es esto y no hay
          # nada más. Los permisos de Hobo **deniegan por defecto**, así que un
          # modelo con `include Hobo::Model` y sin ellos es una aplicación donde
          # nadie puede darse de alta.
          lines.concat(<<~'RUBY'.lines.map(&:chomp))
            # --- Permissions ---
            #
            # Signing up is open, and after that a person is the only one who can
            # change their own account.
            def create_permitted?  = true
            def update_permitted?  = acting_user == self
            def destroy_permitted? = false
            def view_permitted?(_field) = true
          RUBY
          return lines.join("\n") + "\n"
        end

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

    end

  end
end
