require_relative "../browser_helper"

# La × de un mensaje. No tenía prueba de navegador ninguna -- ni de una
# implementación ni de la otra -- y es el comportamiento que más veces se ve en
# una aplicación: sale en cada flash.
#
# Está en el catálogo y no en el tema porque un mensaje del que no te puedes
# deshacer es un fallo, no una cuestión de gusto: las alertas descartables de
# Bootstrap necesitan el JavaScript de Bootstrap, que una aplicación con el tema
# `clean` no tiene y no va a tener.
module DismissBehaviour

  MARKUP = <<~HTML
    <div id="mensaje" data-rapid='{"dismiss":{}}'>
      Guardado.
      <button data-rapid-target="dismiss:button" data-rapid-action="dismiss:dismiss" hidden>x</button>
    </div>
  HTML

  # El botón viene escondido y el comportamiento lo enseña, por lo mismo que el
  # autosubmit esconde el suyo: sin JavaScript, una × que no hace nada es peor
  # que no tener ×.
  def test_the_button_only_appears_when_something_can_do_it
    assert @page.find("button", :visible => :all).visible?
  end

  def test_it_takes_the_message_away
    @page.find("button").click

    assert_empty @page.all("#mensaje", :visible => :all)
  end

end

BrowserBench.contract(DismissBehaviour)
