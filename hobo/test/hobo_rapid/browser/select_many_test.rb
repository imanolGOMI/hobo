require_relative "../browser_helper"

# <select-many>: pick from a select and the choice becomes a row with a hidden
# input; take the row away and the option comes back.
class SelectManyTest < Minitest::Test

  MARKUP = <<~HTML
    <div data-controller="rapid-select-many">
      <select data-rapid-select-many-target="select" data-action="change->rapid-select-many#add">
        <option value="">--</option>
        <option value="1">Uno</option>
        <option value="2">Dos</option>
      </select>

      <ul data-rapid-select-many-target="items"></ul>

      <li data-rapid-select-many-target="template" hidden>
        <span data-rapid-select-many-label></span>
        <input type="hidden" name="story[task_ids][]" disabled>
        <button data-action="rapid-select-many#remove">quitar</button>
      </li>
    </div>
  HTML

  def setup
    skip BrowserBench.why_not unless BrowserBench.ready?
    @page = BrowserBench.visit("rapid-select-many", MARKUP)
  end

  def choose(text) = @page.find("select").select(text)
  def rows = @page.all("ul[data-rapid-select-many-target='items'] > *", :visible => :all)

  def test_choosing_an_option_adds_a_row_with_its_value
    choose("Uno")

    assert_equal 1, rows.length
    assert_equal "Uno", rows.first.find("span", :visible => :all).text
    assert_equal "1", rows.first.find("input[type=hidden]", :visible => :all).value
  end

  # The hidden input of the template is disabled so the template itself is never
  # submitted; the copy has to be enabled or the choice never reaches Rails.
  def test_the_hidden_input_of_a_row_is_submitted
    choose("Uno")

    refute rows.first.find("input[type=hidden]", :visible => :all).disabled?
  end

  def test_an_option_already_chosen_cannot_be_chosen_twice
    choose("Uno")

    assert @page.find("option[value='1']", :visible => :all).disabled?
  end

  def test_removing_a_row_gives_the_option_back
    choose("Uno")
    rows.first.find("button", :visible => :all).click

    assert_empty rows
    refute @page.find("option[value='1']", :visible => :all).disabled?
  end

  def test_several_choices_pile_up
    choose("Uno")
    choose("Dos")

    assert_equal %w[1 2], rows.map { |r| r.find("input[type=hidden]", :visible => :all).value }
  end

end
