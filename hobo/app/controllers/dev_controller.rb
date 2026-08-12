# Become somebody else, in development, in one click.
#
# This is the other half of the user changer in the navigation bar, and it is
# the tool that makes Hobo's permissions worth writing: you declare
# `view_permitted?` and then you *look*, as each person, without logging out and
# in again. Checking permissions by logging in and out is checking them once.
#
# It is guarded three times over, and none of the three is redundant:
#
#   1. the route is not drawn in production (hobo/config/routes.rb),
#   2. nor unless `config.hobo.developer_features` is on,
#   3. and this checks again before doing anything.
#
# A way to become any user is a developer's tool. It has to be impossible to
# switch on by accident, and hard to switch on on purpose.
class DevController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)

  # Rails 8's authentication generator puts `require_authentication` on every
  # controller, and being sent to the login page is the one thing this must not
  # do -- it exists precisely to change who is logged in.
  allow_unauthenticated_access if respond_to?(:allow_unauthenticated_access)

  # Y los que puso **la aplicacion**, que son otros.
  #
  # `allow_unauthenticated_access` solo levanta el filtro de Rails. Una
  # aplicacion que viene de Hobo 2 tiene el suyo en su `ApplicationController`
  # --`before_action { login_required unless User.count == 0 }`-- y este
  # controlador hereda de ella, asi que lo heredaba tambien: elegir un usuario
  # en el menu redirigia a `/login` y no cambiaba nada. Desde fuera «el selector
  # no hace nada», sin error en ninguna parte.
  #
  # Se quitan **todos** los `before_action` heredados y no una lista: los nombres
  # los pone cada aplicacion y no hay forma de saberlos. Los suyos se declaran
  # despues, para que esto no se los lleve por delante.
  _process_action_callbacks.select { |callback| callback.kind == :before }.each do |callback|
    skip_before_action callback.filter, :raise => false
  end

  before_action :developer_modes_only
  # ...and skipping that filter also skips reading the cookie, because Rails 8
  # resumes the session *inside* it. Without this, "be nobody" had nothing to
  # end: `terminate_session` went looking for `Current.session` and found nil.
  # The same trap the model controllers fell into, one controller further on.
  before_action :resume_session_if_any

  def set_current_user
    # A blank choice means "be nobody", which is the first option in the menu
    # and how you look at your own application as a stranger sees it.
    become(find_user)
    redirect_back(:fallback_location => "/")
  end

  private

  def developer_modes_only
    return if !Rails.env.production? && Rails.application.config.hobo.developer_features
    head :forbidden
  end

  def resume_session_if_any
    send(:resume_session) if respond_to?(:resume_session, true)
  rescue StandardError
    nil
  end

  def user_model
    %w[User Account].filter_map { |name| Object.const_get(name) rescue nil }.first
  end

  # Found by whatever the application calls the thing people log in with, the
  # same list the first-user page uses.
  def find_user
    model = user_model
    return nil if model.nil?
    return model.find_by(:id => params[:id]) if params[:id].present?

    field = (%w[email_address email login name] & model.column_names).first
    return nil if field.nil?
    value = params[field]
    return nil if value.blank?
    model.find_by(field => value)
  end

  # Whichever session the application has. Rails 8's generator gives
  # `start_new_session_for`; an application on Hobo's own user model has
  # `current_user=` instead. A blank choice means "be nobody", which is how you
  # look at your own application as a stranger sees it.
  # Los dos sitios donde puede vivir «quien eres», y por ese orden.
  #
  # La sesion de Rails 8 es una **fila en una tabla**: `start_new_session_for`
  # hace `user.sessions.create!`. Una aplicacion que viene de Hobo 2 no tiene ni
  # la tabla ni el `has_many`, asi que ahi no revienta el metodo: revienta con
  # `undefined method 'sessions'` y el selector se quedaba sin hacer nada
  # visible. Es la misma tabla que el aviso del `hobo update` pide crear, y
  # hasta que se cree, esto tiene que seguir funcionando -- es la herramienta
  # con la que se mira la aplicacion recien traida.
  #
  # La otra es la de Hobo, que guarda el usuario en la sesion de Rails y no
  # necesita tabla ninguna. Sirve para las dos.
  def become(user)
    return terminate if user.nil?

    if respond_to?(:start_new_session_for, true) && user.respond_to?(:sessions)
      send(:start_new_session_for, user)
    elsif respond_to?(:current_user=, true)
      self.current_user = user
    end
  end

  # «Ser nadie», que es la primera opcion del menu y como se mira la aplicacion
  # con los ojos de quien no ha entrado.
  #
  # Las dos sesiones otra vez, y aqui hacia falta mas cuidado que al entrar: la
  # de Rails 8 solo se puede cerrar si existe --`terminate_session` hace
  # `Current.session.destroy`-- y en una aplicacion traida de Hobo 2 no existe
  # nunca. Elegir «Invitado» contestaba `undefined method 'destroy' for nil`.
  #
  # Y se cierran **las dos**: quien haya entrado por Rails tiene la suya, quien
  # haya entrado por aqui tiene la de Hobo, y salir a medias deja al usuario
  # dentro por el otro lado.
  def terminate
    send(:terminate_session) if respond_to?(:terminate_session, true) && rails_session?
    self.current_user = nil if respond_to?(:current_user=, true)
  end

  def rails_session?
    defined?(::Current) && ::Current.try(:session).present?
  rescue StandardError
    false
  end

end
