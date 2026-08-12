# El contrato del comportamiento: **lo dice el marcado, no el JavaScript**.
#
# Un `<input-many>` no es «un controlador de Stimulus»: es una lista a la que se
# le pueden añadir y quitar filas. Eso lo dice el html:
#
#   <div class="input-many" data-rapid='{"input-many":{"prefix":"book[tags]"}}'>
#     <div data-rapid-target="input-many:item"> … </div>
#     <button data-rapid-action="input-many:add">+</button>
#   </div>
#
# Quién lo ejecuta viene después y es intercambiable: hoy Stimulus, que es lo
# que trae Rails; con `hobo_jquery` puesto, jQuery. El catálogo no se entera.
#
# **Es el contrato de Hobo 2**, con su mismo nombre (`data-rapid`) a propósito:
# una vista DRYML traída de una aplicación vieja ya lo lleva escrito, y le sirve
# igual. Aquello lo tenía bien: `hobo_rapid` pintaba los atributos y no traía ni
# una línea de JavaScript; el arranque y la implementación eran del plugin.
#
# Lo que se perdió al portarlo fue justo eso: el marcado pasó a decir
# `data-controller="rapid-input-many"`, que es vocabulario de un framework
# concreto, y con ello la posibilidad de que hubiera otro.

require "json"

module HoboRapid

  module Behaviour

    class << self

      # `data-rapid='{"input-many": {"prefix": "…"}}'` -- qué es esto y con qué
      # ajustes. Varios comportamientos pueden vivir en el mismo elemento.
      def declare(name, options = {})
        { :"data-rapid" => { name.to_s => normalise(options) }.to_json }
      end

      # `data-rapid-action="input-many:add"` -- qué hace este botón.
      def action(name, action)
        { :"data-rapid-action" => "#{name}:#{action}" }
      end

      # `data-rapid-target="input-many:item"` -- qué papel tiene esta parte
      # dentro del comportamiento.
      def target(name, target)
        { :"data-rapid-target" => "#{name}:#{target}" }
      end

      private

      # Las claves viajan como se escriben en el html: `add_hook` es
      # `add-hook`. Es lo que hacía Hobo 2 y lo que espera quien lea el JSON
      # desde JavaScript sin traducir nada.
      def normalise(options)
        options.to_h { |key, value| [key.to_s.tr("_", "-"), value] }
      end

    end

  end

end
