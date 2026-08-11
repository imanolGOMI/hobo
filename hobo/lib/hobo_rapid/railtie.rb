require 'hobo_rapid'
require 'rails'
module HoboRapid
  class Railtie < Rails::Railtie

    # Al final de cada peticion, los params que nadie recogio.
    #
    # Aqui y no dentro del tag: un tag no sabe si el que le paso el param se
    # equivoco de nombre o si es un extend legitimo que lo recoge mas abajo. Al
    # acabar la peticion ya no hay duda, y ademas se dice todo de una vez en vez
    # de una linea suelta en medio de la pagina.
    initializer "hobo_rapid.unclaimed_params" do
      ActiveSupport::Notifications.subscribe("process_action.action_controller") do
        Hobo.warn_about_unclaimed_params if defined?(Hobo) && Hobo.respond_to?(:warn_about_unclaimed_params)
      end
    end

  end
end
