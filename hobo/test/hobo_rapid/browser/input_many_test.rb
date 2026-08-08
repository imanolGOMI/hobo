require_relative "../browser_helper"

# <input-many>, the list of form rows a user can grow and shrink. It is the
# signature interactive tag of Hobo, it was 185 lines of jQuery, and it is the
# first behaviour ported to Stimulus.
class InputManyTest < Minitest::Test

  MARKUP = <<~HTML
    <ul data-controller="rapid-input-many"
        data-rapid-input-many-prefix-value="story[tasks]"
        data-rapid-input-many-minimum-value="0">

      <li data-rapid-input-many-target="template" hidden>
        <input name="story[tasks][-1][title]" id="story_tasks_-1_title">
        <button data-action="rapid-input-many#add">add</button>
        <button data-action="rapid-input-many#remove">remove</button>
      </li>

      <li data-rapid-input-many-target="item">
        <input name="story[tasks][0][title]" id="story_tasks_0_title" value="primera">
        <button data-action="rapid-input-many#add">add</button>
        <button data-action="rapid-input-many#remove">remove</button>
      </li>

      <li data-rapid-input-many-target="empty" hidden>
        <input class="empty-input" name="story[tasks][]" value="">
      </li>
    </ul>
  HTML

  def setup
    skip BrowserBench.why_not unless BrowserBench.ready?
    @page = BrowserBench.visit("rapid-input-many", MARKUP)
  end

  def rows = @page.all("li[data-rapid-input-many-target='item']", :visible => :all)
  def names = rows.map { |row| row.find("input", :visible => :all)[:name] }
  def add_on(row) = row.all("button", :visible => :all).first.click
  def remove_on(row) = row.all("button", :visible => :all).last.click

  def test_the_template_row_is_never_submitted
    template = @page.find("li[data-rapid-input-many-target='template']", :visible => :all)

    assert template.find("input", :visible => :all).disabled?, "el input de la plantilla debe ir deshabilitado"
  end

  def test_adding_a_row_clones_the_template_and_enables_it
    add_on(rows.first)

    assert_equal 2, rows.length
    refute rows.last.find("input", :visible => :all).disabled?, "la fila nueva debe poder enviarse"
  end

  # The whole point of the renumbering: Rails reads the index out of the name.
  def test_the_rows_are_numbered_from_zero_with_no_gaps
    add_on(rows.first)
    add_on(rows.last)

    assert_equal ["story[tasks][0][title]", "story[tasks][1][title]", "story[tasks][2][title]"], names
  end

  def test_removing_a_row_in_the_middle_renumbers_the_rest
    add_on(rows.first)
    add_on(rows.last)
    remove_on(rows[1])

    assert_equal 2, rows.length
    assert_equal ["story[tasks][0][title]", "story[tasks][1][title]"], names
  end

  def test_the_ids_and_labels_are_renumbered_too
    add_on(rows.first)

    assert_equal ["story_tasks_0_title", "story_tasks_1_title"],
                 rows.map { |row| row.find("input", :visible => :all)[:id] }
  end

  # Only the last row offers "add": otherwise the order of what you are building
  # stops meaning anything.
  def test_only_the_last_row_offers_to_add
    add_on(rows.first)

    shown = rows.map { |row| row.all("button", :visible => true).map(&:text) }
    assert_equal [["remove"], ["add", "remove"]], shown
  end

  def test_the_empty_row_shows_only_while_the_list_is_empty
    empty = @page.find("li[data-rapid-input-many-target='empty']", :visible => :all)
    refute empty.visible?, "con una fila, la fila vacia no se enseña"

    remove_on(rows.first)

    assert empty.visible?, "sin filas, la fila vacia aparece"
    refute empty.find("input", :visible => :all).disabled?, "y su input se envia"
  end

  def test_a_minimum_hides_the_remove_button
    @page.execute_script("document.querySelector('ul').dataset.rapidInputManyMinimumValue = '1'")
    add_on(rows.first)
    remove_on(rows.last)

    assert_equal 1, rows.length
    assert_empty rows.first.all("button", :visible => true).map(&:text) & ["remove"],
                 "en el minimo no se puede quitar"
  end

end
