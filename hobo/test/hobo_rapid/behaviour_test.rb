require "test_helper"
require "json"

# El contrato del comportamiento, que es lo que el catálogo escribe en el
# marcado para que **otro** lo ejecute.
#
# Existe porque el catálogo decía `data-controller="rapid-input-many"`: el
# nombre de un framework concreto dentro del html, y con él la imposibilidad de
# que hubiera otra implementación. Hobo 2 lo tenía bien -- `data-rapid` y nada
# más -- y esto lo recupera, con el mismo nombre a propósito: una vista traída
# de una aplicación vieja ya lo lleva escrito.
class BehaviourTest < Minitest::Test

  def declared(attrs) = JSON.parse(attrs[:"data-rapid"])

  def test_it_says_what_a_thing_is
    attrs = HoboRapid::Behaviour.declare("input-many", :prefix => "book[tags]", :minimum => 0)

    assert_equal({ "input-many" => { "prefix" => "book[tags]", "minimum" => 0 } }, declared(attrs))
  end

  # Un comportamiento sin ajustes sigue diciendo que está: `{}` no es lo mismo
  # que no estar.
  def test_a_behaviour_with_nothing_to_configure
    assert_equal({ "dismiss" => {} }, declared(HoboRapid::Behaviour.declare("dismiss")))
  end

  # Las claves viajan como se escriben en html, con guiones: es lo que hacía
  # Hobo 2 y lo que espera quien lea el JSON sin traducir nada.
  def test_underscores_become_hyphens
    attrs = HoboRapid::Behaviour.declare("input-many", :add_hook => "avisa()")

    assert_equal({ "input-many" => { "add-hook" => "avisa()" } }, declared(attrs))
  end

  def test_what_a_button_does
    assert_equal({ :"data-rapid-action" => "input-many:add" },
                 HoboRapid::Behaviour.action("input-many", "add"))
  end

  def test_what_a_part_is
    assert_equal({ :"data-rapid-target" => "input-many:item" },
                 HoboRapid::Behaviour.target("input-many", "item"))
  end

  # Y lo que **no** hace: nombrar a nadie. Si esto vuelve a fallar es que el
  # catálogo ha vuelto a atarse a una implementación.
  def test_nothing_here_names_a_framework
    todo = [
      HoboRapid::Behaviour.declare("input-many", :prefix => "x"),
      HoboRapid::Behaviour.action("input-many", "add"),
      HoboRapid::Behaviour.target("input-many", "item"),
    ].map { |attrs| attrs.to_a.flatten.join(" ") }.join(" ")

    refute_includes todo, "controller"
    refute_includes todo, "stimulus"
    refute_includes todo, "jquery"
  end

end
