require_relative "../browser_helper"

# Avisar antes de salir de una página con cambios sin guardar.
#
# El diálogo es del navegador y no se puede conducir, así que la prueba dispara
# el evento y mira si el comportamiento pidió que se preguntara -- que es la
# única decisión que toma.
#
# El marcado no lleva acciones, y eso es a propósito: el contrato no sabe decir
# «con este evento», y en un formulario el evento que se supone es `submit`,
# justo el contrario del que hace falta. El comportamiento se ata los suyos.
module BeforeUnloadBehaviour

  MARKUP = <<~HTML
    <form data-rapid='{"before-unload":{}}'>
      <input id="titulo" name="title">
    </form>
  HTML

  def would_warn?
    @page.evaluate_script(<<~JS)
      (function () {
        const event = new Event("beforeunload", { cancelable: true })
        window.dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS
  end

  def change_something
    @page.execute_script("document.querySelector('#titulo').dispatchEvent(new Event('change', { bubbles: true }))")
  end

  def test_a_page_nobody_touched_lets_you_leave
    refute would_warn?
  end

  def test_changing_something_makes_it_ask
    change_something

    assert would_warn?
  end

  # Enviar el formulario no es irse con cambios sin guardar.
  def test_submitting_the_form_clears_it
    change_something
    @page.execute_script("document.querySelector('form').dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))")

    refute would_warn?
  end

end

BrowserBench.contract(BeforeUnloadBehaviour)
