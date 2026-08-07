require_relative "../browser_helper"

# Warn before leaving a page with unsaved changes.
#
# The dialog itself belongs to the browser and cannot be driven, so the test
# fires the event and looks at whether the controller asked for it -- which is
# the only decision the controller makes.
class BeforeUnloadTest < Minitest::Test

  MARKUP = <<~HTML
    <form data-controller="rapid-before-unload"
          data-action="change->rapid-before-unload#touch submit->rapid-before-unload#release">
      <input id="titulo" name="title">
    </form>
  HTML

  def setup
    skip BrowserBench.why_not unless BrowserBench.ready?
    @page = BrowserBench.visit("rapid-before-unload", MARKUP)
  end

  def would_warn?
    @page.evaluate_script(<<~JS)
      (function () {
        const event = new Event("beforeunload", { cancelable: true })
        window.dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS
  end

  def test_a_page_nobody_touched_lets_you_leave
    refute would_warn?
  end

  def test_changing_something_makes_it_ask
    @page.find("#titulo").send_keys("hola")
    @page.execute_script("document.querySelector('#titulo').dispatchEvent(new Event('change', { bubbles: true }))")

    assert would_warn?
  end

  # Sending the form is not leaving with unsaved changes.
  def test_submitting_the_form_clears_it
    @page.execute_script("document.querySelector('#titulo').dispatchEvent(new Event('change', { bubbles: true }))")
    @page.execute_script("document.querySelector('form').dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))")

    refute would_warn?
  end

end
