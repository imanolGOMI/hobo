module Hobo
  module Controller
    module AuthenticationSupport

      # Todo lo de aquí abajo pregunta `current_user`, y hasta ahora este módulo
      # daba por hecho que ya estaba puesto. Lo está en los controladores de
      # modelo, porque `Hobo::Controller` reparte el helper al incluirse -- pero
      # una aplicación de Hobo 2 pone esto **en su `ApplicationController`**, que
      # es de donde cuelgan también los que no son de modelo.
      #
      # Y ahí se rompía: `DevController` (el selector de «cambiar de usuario»),
      # los de sesión y los de claves heredan los `before_action` que la
      # aplicación escribió --`login_required`, la multitenencia-- y ninguno de
      # ellos sabía contestar quién pregunta. En amenti era un 500 con
      # «undefined local variable or method 'current_user'» antes de entrar en
      # la acción, y le pasa a cualquiera que mire el usuario desde arriba, que
      # es lo corriente.
      #
      # La respuesta no se escribe otra vez aquí: se piden los mismos helpers que
      # reparte `Hobo::Controller`, para que quien pregunta reciba **la misma**
      # respuesta -- incluido el `Guest` cuando no hay nadie.
      #
      # Son dos, y por lo mismo. `current_user` lo contesta el de permisos; y
      # cuando la respuesta es que no, `access_denied` manda a `login_url`, que
      # es del de rutas. Con uno solo el 500 no desaparecía: se movía una línea
      # más abajo, de «undefined current_user» a «undefined login_url».
      def self.included(base)
        return unless base.respond_to?(:helper_method)
        HoboPermissionsHelper.add_to_controller(base)
        HoboRouteHelper.add_to_controller(base)
      end

      # Filter method to enforce a login requirement.
      def logged_in?
        not current_user.guest?
      end

      # Guardar quien eres en la sesion.
      #
      # Estaba en `Hobo::Controller` y **lo llama esto**: `login_required` lo usa
      # tres lineas mas abajo. Un controlador que pide la autenticacion de Hobo
      # sin ser de modelo se quedaba sin el, y no fallaba de forma ruidosa: el
      # selector de «cambiar de usuario» buscaba a quien ponerse, no encontraba
      # ni la sesion de Rails 8 ni esta, y redirigia tan contento sin haber
      # cambiado nada. Un boton que no hace nada y no dice nada.
      def current_user=(new_user)
        session[:user] = (new_user.nil? || new_user.guest?) ? nil : new_user.typed_id
        @current_user = new_user
      end


      # Check if the user is authorized.
      #
      # Override this method in your controllers if you want to restrict access
      # to only a few actions or if you want to check if the user
      # has the correct rights.
      #
      # Example:
      #
      #  # only allow nonbobs
      #  def authorize?
      #    current_user.login != "bob"
      #  end
      def authorized?
        true
      end

      #
      # To require logins for all actions, use this in your controllers:
      #
      #   before_action :login_required
      #
      # To require logins for specific actions, use this in your controllers:
      #
      #   before_action :login_required, :only => [ :edit, :update ]
      #
      # To skip this in a subclassed controller:
      #
      #   skip_before_action :login_required
      #
      def login_required(user_model=nil)
        auth_model = user_model || Hobo::Model::UserBase.default_user_model
        if current_user.guest?
          username, passwd = get_auth_data
          self.current_user = auth_model.authenticate(username, passwd) || nil if username && passwd && auth_model
        end
        if logged_in? && authorized? && (user_model.nil? || current_user.is_a?(user_model))
          true
        else
          access_denied(auth_model)
        end
      end


      # Store the URI of the current request in the session.
      #
      # We can return to this location by calling #redirect_back_or_default.
      def store_location
        session[:return_to] = request.fullpath
      end

      # Redirect to the URI stored by the most recent store_location call or
      # to the passed default.
      def redirect_back_or_default(default)
        session[:return_to] ? redirect_to(session[:return_to]) : redirect_to(default)
        session[:return_to] = nil
      end

      # When called with before_action :login_from_cookie will check for an :auth_token
      # cookie and log the user back in if apropriate
      def login_from_cookie
        if (user = authenticated_user_from_cookie)
          user.remember_me
          self.current_user = user
          create_auth_cookie
        end
      end


      def authenticated_user_from_cookie
        !logged_in? and
            cookie = cookies[:auth_token] and
            (token, model_name = cookie.split) and
            user_model = model_name&.safe_constantize and
            user = user_model.find_by_remember_token(token) and
            user.remember_token? and
            user
      end

      def create_auth_cookie
        cookies[:auth_token] = { :value => "#{current_user.remember_token} #{current_user.class.name}",
                                 :expires => current_user.remember_token_expires_at }
      end

      private
      @@http_auth_headers = %w(X-HTTP_AUTHORIZATION HTTP_AUTHORIZATION Authorization)
      # gets BASIC auth info
      def get_auth_data
        auth_key  = @@http_auth_headers.detect { |h| request.env.has_key?(h) }
        auth_data = request.env[auth_key].to_s.split unless auth_key.blank?
        username, pw = if auth_data && auth_data[0] == 'Basic'
                         Base64.decode64(auth_data[1]).split(':')[0..1]
                       else
                         [nil, nil]
                       end
      end

    end
  end
end
