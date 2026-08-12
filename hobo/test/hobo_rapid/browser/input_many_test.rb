require_relative "../browser_helper"

# <input-many>, la lista de filas de formulario que se puede hacer crecer y
# encoger. Es el tag interactivo con más historia de Hobo -- 185 líneas de
# jQuery en Hobo 2 -- y es donde el contrato se nota más: una fila nueva se
# clona, se renumera y trae dentro su propio comportamiento.
#
# El marcado es el que **escribe el catálogo**, sin nombrar a nadie, y estas
# pruebas corren contra las dos implementaciones.
module InputManyBehaviour

  MARKUP = <<~HTML
    <ul data-rapid='{"input-many":{"prefix":"story[tasks]","minimum":0}}'>

      <li data-rapid-target="input-many:template" hidden>
        <input name="story[tasks][-1][title]" id="story_tasks_-1_title">
        <button data-rapid-action="input-many:add">add</button>
        <button data-rapid-action="input-many:remove">remove</button>
      </li>

      <li data-rapid-target="input-many:item">
        <input name="story[tasks][0][title]" id="story_tasks_0_title" value="primera">
        <button data-rapid-action="input-many:add">add</button>
        <button data-rapid-action="input-many:remove">remove</button>
      </li>

      <li data-rapid-target="input-many:empty" hidden>
        <input class="empty-input" name="story[tasks][]" value="">
        <button data-rapid-action="input-many:add">add</button>
      </li>
    </ul>
  HTML

  # Los selectores son los del contrato, no los de ninguna implementación. Que
  # una fila recién añadida se encuentre por aquí es parte de lo que se prueba:
  # si una de las dos escribe solo sus atributos, esto no la ve.
  def rows = @page.all("li[data-rapid-target='input-many:item']", :visible => :all)
  def names = rows.map { |row| row.find("input", :visible => :all)[:name] }
  def add_on(row) = row.all("button", :visible => :all).first.click
  def remove_on(row) = row.all("button", :visible => :all).last.click

  def test_the_template_row_is_never_submitted
    template = @page.find("li[data-rapid-target='input-many:template']", :visible => :all)

    assert template.find("input", :visible => :all).disabled?, "el input de la plantilla debe ir deshabilitado"
  end

  def test_adding_a_row_clones_the_template_and_enables_it
    add_on(rows.first)

    assert_equal 2, rows.length
    refute rows.last.find("input", :visible => :all).disabled?, "la fila nueva debe poder enviarse"
  end

  # La fila nueva **deja de decir que es una plantilla**. Aquí es donde el
  # contrato se rompía: Stimulus ponía su atributo y dejaba el neutro como
  # estaba, así que la página acababa con cinco filas que decían ser plantillas.
  def test_a_new_row_says_what_it_is
    add_on(rows.first)

    assert_equal 2, rows.length
    assert_equal 1, @page.all("li[data-rapid-target='input-many:template']", :visible => :all).length
  end

  # El sentido entero de renumerar: Rails lee el índice del nombre.
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

  # Solo la última fila ofrece "add": si no, el orden de lo que estás
  # construyendo deja de significar nada.
  def test_only_the_last_row_offers_to_add
    add_on(rows.first)

    shown = rows.map { |row| row.all("button", :visible => true).map(&:text) }
    assert_equal [["remove"], ["add", "remove"]], shown
  end

  # Quitar la última fila no puede dejar la página sin manera de volver a
  # empezar. El `+` vive en la última fila, así que al quitarla no quedaba
  # ninguno: quitabas la única etiqueta de un libro y ya no podías ponerle otra
  # sin recargar. El de la fila de "no hay nada" es el que queda.
  def test_removing_the_last_row_still_leaves_a_way_back
    remove_on(rows.first)

    assert_empty rows
    botones = @page.all("[data-rapid-action='input-many:add']", :visible => true)
    refute_empty botones, "sin filas no queda ningun boton para anadir: el control desaparece"

    botones.first.click

    assert_equal 1, rows.length
    refute rows.first.find("input", :visible => :all).disabled?, "la fila que vuelve tiene que poder enviarse"
  end

  def test_the_empty_row_shows_only_while_the_list_is_empty
    empty = @page.find("li[data-rapid-target='input-many:empty']", :visible => :all)
    refute empty.visible?, "con una fila, la fila vacia no se enseña"

    remove_on(rows.first)

    assert empty.visible?, "sin filas, la fila vacia aparece"
    refute empty.find("input", :visible => :all).disabled?, "y su input se envia"
  end

end

BrowserBench.contract(InputManyBehaviour)

# El mínimo, que se declara en el marcado y no se toca luego: quitar la última
# fila tiene que **decirse**, porque unos parámetros a los que simplemente les
# falta la clave se leen como "déjalo como está".
module InputManyMinimumBehaviour

  MARKUP = <<~HTML
    <ul data-rapid='{"input-many":{"prefix":"story[tasks]","minimum":1}}'>

      <li data-rapid-target="input-many:template" hidden>
        <input name="story[tasks][-1][title]" id="story_tasks_-1_title">
        <button data-rapid-action="input-many:add">add</button>
        <button data-rapid-action="input-many:remove">remove</button>
      </li>

      <li data-rapid-target="input-many:item">
        <input name="story[tasks][0][title]" id="story_tasks_0_title" value="primera">
        <button data-rapid-action="input-many:add">add</button>
        <button data-rapid-action="input-many:remove">remove</button>
      </li>
    </ul>
  HTML

  def rows = @page.all("li[data-rapid-target='input-many:item']", :visible => :all)

  def test_at_the_minimum_nothing_can_be_removed
    assert_equal 1, rows.length
    assert_empty rows.first.all("button", :visible => true).map(&:text) & ["remove"],
                 "en el minimo no se puede quitar"
  end

  def test_above_the_minimum_it_can
    rows.first.all("button", :visible => :all).first.click

    assert_equal 2, rows.length
    assert_includes rows.last.all("button", :visible => true).map(&:text), "remove"
  end

end

BrowserBench.contract(InputManyMinimumBehaviour)
