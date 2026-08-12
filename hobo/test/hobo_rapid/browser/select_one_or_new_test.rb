require_relative "../browser_helper"

# <select-one-or-new>: elegir un registro que existe, o hacer uno aquí mismo.
#
# Todo el trabajo en el navegador es un invariante, y vale la pena decirlo
# claro: **se envía exactamente una de las dos mitades**. Las dos llegarían al
# `attributes=` del modelo y la segunda ganaría en silencio, que es el fallo que
# se cuenta como «a veces guarda otra cosa».
module SelectOneOrNewBehaviour

  MARKUP = <<~HTML
    <div data-rapid='{"select-one-or-new":{}}'>
      <select data-rapid-target="select-one-or-new:select"
              data-rapid-action="select-one-or-new:change"
              name="movie[category_id]">
        <option value="">--</option>
        <option value="1">Drama</option>
        <option value="__new__">Nueva categoria</option>
      </select>

      <div data-rapid-target="select-one-or-new:fields" hidden>
        <input type="text" name="movie[category][name]">
      </div>
    </div>
  HTML

  def select = @page.find("select", :visible => :all)
  def fields = @page.find("div[data-rapid-target='select-one-or-new:fields']", :visible => :all)
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

  # La mitad que no se usa tiene que ser *no enviable*, no solo invisible. El
  # select se queda funcionando --se puede cambiar de opinión-- así que lo que
  # se va es su nombre, porque un campo sin nombre no se envía.
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

end

BrowserBench.contract(SelectOneOrNewBehaviour)

# Un formulario que vuelve de un error de validación trae «nuevo» ya elegido, y
# tiene que volver **abierto**: si no, lo que la persona escribió está ahí,
# invisible y deshabilitado.
module SelectOneOrNewReopenBehaviour

  MARKUP = SelectOneOrNewBehaviour::MARKUP.sub('<option value="__new__">', '<option value="__new__" selected>')

  def test_it_opens_on_connect_when_new_is_already_chosen
    assert @page.find("div[data-rapid-target='select-one-or-new:fields']", :visible => :all).visible?
    refute @page.find("input[type=text]", :visible => :all).disabled?
  end

end

BrowserBench.contract(SelectOneOrNewReopenBehaviour)
