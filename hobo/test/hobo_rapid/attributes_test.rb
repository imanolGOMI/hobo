require "test_helper"
require "hobo_rapid/tags/page"

# Lo que sale escrito **dentro de la etiqueta**.
#
# Los dos casos de aqui salieron de mirar la portada de amenti actualizada, y
# ninguno de los dos daba error: la pagina se pintaba entera y el navegador se
# quedaba con la mitad de lo que le habiamos dicho.
class AttributesTest < Minitest::Test

  # `tag("ul", all_attributes.merge("class" => "nav"))`: la clave del que llama
  # es `:class` y esta es `"class"`, y un Hash se queda con las dos. Salia
  # `<ul class="main-nav" class="nav">`, y de dos atributos iguales un navegador
  # lee el primero y tira el segundo.
  def test_the_same_attribute_written_twice_comes_out_once
    Rapid.define(:two_classes) { tag("div", { :class => "a" }.merge("class" => "b")) }

    html = Rapid.render(:two_classes)

    assert_equal 1, html.scan(/class=/).length
    assert_includes html, %(class="a b"), "las dos clases, no la ultima"
  end

  def test_underscores_and_dashes_are_the_same_name
    Rapid.define(:two_ways) { tag("div", { :data_turbo => "false" }.merge("data-turbo" => "true")) }

    assert_equal 1, Rapid.render(:two_ways).scan(/data-turbo/).length
  end

  # Un atributo declarado es cosa del tag -- `<navigation current="Inicio">` le
  # dice a la barra cual es la pestana de ahora -- y no significa nada en HTML.
  # Esparcir `all_attributes` lo mandaba tal cual: `<ul current="Inicio">`.
  def test_a_declared_attribute_does_not_reach_the_markup
    html = Rapid.render(:navigation, { :current => "Inicio", :class => "main-nav" })

    refute_includes html, "current=", "`current` es del tag, no del <ul>"
    assert_includes html, "main-nav"
  end

  # Y lo que no declara sigue pasando: es lo que hace `merge-attrs`.
  def test_what_the_tag_does_not_declare_still_goes_through
    assert_includes Rapid.render(:navigation, { :id => "barra" }), %(id="barra")
  end

  # --- params que nadie recoge -----------------------------------------------
  #
  # `<page><footer:>…</footer:></page>` cuando el param se llamaba `page_footer`:
  # lo que traia el que llamaba desaparecia, sin error y sin hueco. Asi se
  # perdio el pie de amenti con las cinco paginas devolviendo 200.

  def test_a_param_the_tag_never_asks_for_is_written_down
    Rapid.define(:caja) { tag("div", {}, :dentro) }
    Rapid.forget_unclaimed

    Rapid.render(:caja, {}, :dentro => Rapid.markup { text "si" }, :fuera => Rapid.markup { text "no" })

    assert_equal({ :caja => [:fuera] }, Rapid.unclaimed)
  end

  # Y lo que se pasa hacia abajo queda recogido: responde el tag de abajo.
  def test_what_is_handed_on_with_merge_params_is_not_reported
    Rapid.define(:dentro) { param(:hueco) }
    Rapid.define(:fuera) { call_tag(:dentro, {}, :merge_params => true) }
    Rapid.forget_unclaimed

    Rapid.render(:fuera, {}, :hueco => Rapid.markup { text "x" })

    assert_empty Rapid.unclaimed
  end

end
