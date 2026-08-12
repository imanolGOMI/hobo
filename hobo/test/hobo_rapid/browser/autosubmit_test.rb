require_relative "../browser_helper"

# `hot-input` y `filter-menu` eran la misma idea escrita dos veces: enviar el
# formulario cuando algo cambia dentro. Son un comportamiento solo, y ya no hace
# la petición él: el formulario va a Turbo.
module AutosubmitBehaviour

  MARKUP = <<~HTML
    <form action="/" method="get" onsubmit="window.submitted = (window.submitted || 0) + 1; return false;">
      <select data-rapid='{"autosubmit":{}}' data-rapid-action="autosubmit:submit">
        <option value="">--</option>
        <option value="a">A</option>
      </select>
    </form>
  HTML

  def submitted = @page.evaluate_script("window.submitted || 0")

  def test_changing_a_select_sends_the_form
    @page.execute_script("window.submitted = 0")
    @page.find("select").select("A")

    assert_equal 1, submitted
  end

end

BrowserBench.contract(AutosubmitBehaviour)

# Escribiendo se manda **una vez al parar**, no una por tecla. Sin esto, un
# campo que se autoenvía es una tormenta contra el servidor.
module AutosubmitDelayBehaviour

  MARKUP = <<~HTML
    <form action="/" method="get" onsubmit="window.submitted = (window.submitted || 0) + 1; return false;">
      <input id="con-retardo" data-rapid='{"autosubmit":{"delay":150}}' data-rapid-action="autosubmit:submit">
    </form>
  HTML

  def submitted = @page.evaluate_script("window.submitted || 0")

  def test_a_delay_waits_for_the_typing_to_stop
    @page.execute_script("window.submitted = 0")
    @page.find("#con-retardo").send_keys("hola")

    assert_equal 0, submitted, "no se envia mientras se escribe"
    sleep 0.5
    assert_equal 1, submitted, "y se envia una sola vez al parar"
  end

end

BrowserBench.contract(AutosubmitDelayBehaviour)

# El menú se envía solo, así que el botón que lo envía sobra en cuanto hay
# JavaScript: dos maneras de hacer una cosa. El marcado lo trae para quien no lo
# tiene, y el comportamiento lo quita.
module AutosubmitFallbackBehaviour

  MARKUP = <<~HTML
    <form data-rapid='{"autosubmit":{}}' method="get" action="/">
      <select data-rapid-action="autosubmit:submit"><option>uno</option></select>
      <button data-rapid-target="autosubmit:fallback">Filtrar</button>
    </form>
  HTML

  def test_the_fallback_button_is_taken_away
    refute @page.find("button", :visible => :all).visible?,
           "el boton de reserva sobra cuando hay javascript"
  end

end

BrowserBench.contract(AutosubmitFallbackBehaviour)
