require_relative "../browser_helper"

# `hot-input` and `filter-menu` were the same idea written twice: send the form
# when something in it changes. They are one controller now, and it no longer
# does the request itself -- the form goes to Turbo.
class AutosubmitTest < Minitest::Test

  MARKUP = <<~HTML
    <form action="/" method="get" onsubmit="window.submitted = (window.submitted || 0) + 1; return false;">
      <select data-controller="rapid-autosubmit" data-action="change->rapid-autosubmit#submit">
        <option value="">--</option>
        <option value="a">A</option>
      </select>
      <input id="con-retardo" data-controller="rapid-autosubmit"
             data-rapid-autosubmit-delay-value="150"
             data-action="input->rapid-autosubmit#submit">
    </form>
  HTML

  def setup
    skip BrowserBench.why_not unless BrowserBench.ready?
    @page = BrowserBench.visit("rapid-autosubmit", MARKUP)
    @page.execute_script("window.submitted = 0")
  end

  def submitted = @page.evaluate_script("window.submitted")

  def test_changing_a_select_sends_the_form
    @page.find("select").select("A")

    assert_equal 1, submitted
  end

  # Typing sends one request when you stop, not one per keystroke.
  def test_a_delay_waits_for_the_typing_to_stop
    @page.find("#con-retardo").send_keys("hola")

    assert_equal 0, submitted, "no se envia mientras se escribe"
    sleep 0.4
    assert_equal 1, submitted, "y se envia una sola vez al parar"
  end

end
