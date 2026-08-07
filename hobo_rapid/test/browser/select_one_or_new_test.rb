require_relative "../browser_helper"

# <select-one-or-new>: choose an existing record, or make one right here.
#
# The whole job in the browser is one invariant, and it is worth saying plainly:
# **exactly one of the two halves is submitted**. Both would reach the model's
# `attributes=` and the second would quietly win, which is the kind of failure
# that looks like "it saved the wrong thing sometimes".
class SelectOneOrNewTest < Minitest::Test

  MARKUP = <<~HTML
    <div data-controller="rapid-select-one-or-new">
      <select data-rapid-select-one-or-new-target="select"
              data-action="change->rapid-select-one-or-new#change"
              name="movie[category_id]">
        <option value="">--</option>
        <option value="1">Drama</option>
        <option value="__new__">Nueva categoria</option>
      </select>

      <div data-rapid-select-one-or-new-target="fields" hidden>
        <input type="text" name="movie[category][name]">
      </div>
    </div>
  HTML

  def setup
    skip BrowserBench.why_not unless BrowserBench.ready?
    @page = BrowserBench.visit("rapid-select-one-or-new", MARKUP)
  end

  def select = @page.find("select", :visible => :all)
  def fields = @page.find("div[data-rapid-select-one-or-new-target='fields']", :visible => :all)
  def new_input = @page.find("input[type=text]", :visible => :all)

  def test_the_fields_are_hidden_and_unsubmittable_until_asked_for
    refute fields.visible?, "los campos del registro nuevo no deben verse de entrada"
    assert new_input.disabled?, "y no deben enviarse: un input deshabilitado no viaja"
  end

  def test_choosing_new_reveals_the_fields_and_lets_them_be_sent
    select.select("Nueva categoria")

    assert fields.visible?
    refute new_input.disabled?
  end

  # The half that is not being used has to be *unsubmittable*, not just hidden.
  # The select keeps working -- you can change your mind -- so it is its name
  # that goes, because an input with no name is not submitted.
  def test_while_creating_the_select_is_not_submitted
    select.select("Nueva categoria")

    assert select[:name].to_s.empty?, "el select no puede enviarse mientras se crea uno nuevo"
  end

  def test_changing_your_mind_puts_the_select_back
    select.select("Nueva categoria")
    select.select("Drama")

    assert_equal "movie[category_id]", select[:name]
    refute fields.visible?
    assert new_input.disabled?
  end

  # A form re-rendered after a validation error comes back with "new" already
  # chosen, and it has to come back open -- otherwise what the user typed is
  # there, invisible and disabled.
  def test_it_opens_on_connect_when_new_is_already_chosen
    page = BrowserBench.visit("rapid-select-one-or-new",
                              MARKUP.sub('<option value="__new__">', '<option value="__new__" selected>'))

    assert page.find("div[data-rapid-select-one-or-new-target='fields']", :visible => :all).visible?
  end

end
