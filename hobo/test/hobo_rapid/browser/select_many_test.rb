require_relative "../browser_helper"

# <select-many>: se elige del desplegable y cada elección se convierte en una
# fila con su campo oculto; se quita la fila y la opción vuelve.
module SelectManyBehaviour

  MARKUP = <<~HTML
    <div data-rapid='{"select-many":{}}'>
      <select data-rapid-target="select-many:select" data-rapid-action="select-many:add">
        <option value="">--</option>
        <option value="1">Uno</option>
        <option value="2">Dos</option>
      </select>

      <ul data-rapid-target="select-many:items"></ul>

      <li data-rapid-target="select-many:template" hidden>
        <span data-rapid-target="select-many:label"></span>
        <input type="hidden" name="story[task_ids][]" disabled>
        <button data-rapid-action="select-many:remove">quitar</button>
      </li>
    </div>
  HTML

  def choose(text) = @page.find("select").select(text)
  def rows = @page.all("ul[data-rapid-target='select-many:items'] > *", :visible => :all)

  def test_choosing_an_option_adds_a_row_with_its_value
    choose("Uno")

    assert_equal 1, rows.length
    assert_equal "Uno", rows.first.find("span", :visible => :all).text
    assert_equal "1", rows.first.find("input[type=hidden]", :visible => :all).value
  end

  # El campo oculto de la plantilla va deshabilitado para que la plantilla no se
  # envíe nunca; la copia tiene que ir habilitada o la elección no llega a Rails.
  def test_the_hidden_input_of_a_row_is_submitted
    choose("Uno")

    refute rows.first.find("input[type=hidden]", :visible => :all).disabled?
  end

  # Y deja de decir que es la plantilla, como la fila del input-many.
  def test_a_row_is_not_the_template_any_more
    choose("Uno")

    assert_equal 1, @page.all("[data-rapid-target='select-many:template']", :visible => :all).length
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

  def test_two_choices_are_two_rows
    choose("Uno")
    choose("Dos")

    assert_equal 2, rows.length
    assert_equal %w[1 2], rows.map { |row| row.find("input[type=hidden]", :visible => :all).value }
  end

end

BrowserBench.contract(SelectManyBehaviour)
