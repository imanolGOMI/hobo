require "test_helper"
require "hobo_rapid/tags/inputs"
require "hobo_rapid/tags/views"

# **Todos** los tipos de campo, por todas las formas de pintarlos, en todos los
# estados. No una muestra.
#
# Un modelo de Hobo declara sus campos con un tipo, y el tipo es quien decide
# cómo se ve y cómo se edita. Eso son 17 tipos por dos tags polimórficos por
# cuatro estados del valor -- puesto, vacío, nulo, y sin permiso -- y probarlos
# a mano quiere decir probar cuatro y confiar en los otros trece.
#
# La forma de los fallos que caza es siempre la misma: **el tipo raro con el
# valor raro**. Un `decimal` a nil que llama a `strftime`, un `serialized` que
# devuelve un Hash donde se esperaba texto, un `password` que se pinta con su
# contenido dentro. Ninguno de esos aparece pintando un `string`.
#
# Lo que se comprueba son invariantes, no marcado esperado:
#
#   - pintar nunca revienta, con ningún tipo y ningún valor
#   - un campo que no se puede ver **no aparece**, sea del tipo que sea
#   - una contraseña nunca sale escrita en el html
#   - un `<input>` siempre lleva `name`, o lo que se escriba no llega a Rails
class TypeMatrixTest < Minitest::Test

  # Un valor de cada tipo, y su nil. `HoboFields.field_types` es la lista de
  # verdad: si mañana hay un tipo nuevo, esta prueba lo pide.
  VALUES = {
    "boolean" => [true, false],
    "date" => [Date.new(2026, 8, 10)],
    "datetime" => [Time.utc(2026, 8, 10, 12, 30)],
    "time" => [Time.utc(2026, 8, 10, 12, 30)],
    "integer" => [42, 0, -1],
    "decimal" => [BigDecimal("3.14")],
    "float" => [4.5],
    "string" => ["Hola", "", "<script>alert(1)</script>"],
    "email_address" => ["quien@ejemplo.com"],
    "text" => ["Dos\nlineas"],
    "raw_html" => ["<b>hola</b>"],
    "html" => ["<b>hola</b>"],
    "password" => ["secreto-que-no-debe-salir"],
    "raw_markdown" => ["# hola"],
    "markdown" => ["# hola"],
    "serialized" => [{ "a" => 1 }],
    "textile" => ["h1. hola"],
  }.freeze

  # Un modelo de mentira que dice de qué tipo es cada campo y quién puede verlo.
  #
  # `attr_type` es **de clase**, y ese detalle importa: es lo que mira
  # `Rapid.dispatch_type` para saber de qué tipo es un campo, precisamente
  # porque un campo vacío no puede decirlo por sí mismo -- un `date` a nil sigue
  # siendo un date. Un modelo de mentira que lo declarara de instancia probaría
  # otra cosa.
  class Record

    attr_accessor :value

    def initialize(value, viewable: true, editable: true)
      @value = value
      @viewable = viewable
      @editable = editable
    end

    def viewable_by?(_user, _field = nil) = @viewable
    def editable_by?(_user, _field = nil) = @editable

  end

  # Una clase por tipo, porque el tipo lo declara la clase.
  def model_for(type)
    @models ||= {}
    @models[type] ||= begin
      declared = HoboFields.field_types[type] || String
      Class.new(Record) do
        define_singleton_method(:name) { "Record#{type.camelize}" }
        define_singleton_method(:attr_type) { |_field| declared }
      end
    end
  end

  def every_field
    VALUES.each do |type, values|
      (values + [nil]).each do |value|
        [true, false].each do |viewable|
          yield type, value, viewable
        end
      end
    end
  end

  # Un tipo rico de HoboFields **es una clase**, y lo que se lee de la base de
  # datos es una instancia suya, no un String pelado. Pintar con el String
  # pelado prueba otra cosa: el reparto por tipo mira lo que el valor es, y con
  # un String todo cae en la vista genérica -- que es justo la que no se quiere.
  def typed(type, value)
    declared = HoboFields.field_types[type]
    return value unless declared.is_a?(Class) && value.is_a?(String) && declared < String

    declared.new(value)
  end

  def painted(tag, type, value, viewable)
    value = typed(type, value)
    record = model_for(type).new(value, :viewable => viewable)
    outer = Rapid::Tag.new
    Rapid::Context.capture { outer.with_field(:value, record) { outer.call_tag(tag, {}) } }
  end

  # Hay un tipo que sí puede negarse a pintar, y está bien que lo haga: un campo
  # `markdown` necesita una gema que convierta markdown en html, y Hobo no la
  # trae. Lo que se exige entonces es que el error **diga qué instalar** -- un
  # `NoMethodError` en mitad de una página derivada no lo dice.
  def paint_or_explain(tag, type, value)
    painted(tag, type, value, true)
  rescue RuntimeError => e
    assert_match(/gem "|gema/, e.message,
                 "#{type} se ha negado a pintarse sin decir que hace falta: #{e.message}")
    ""
  end

  # --- pintar nunca revienta -----------------------------------------------------

  def test_every_type_can_be_viewed
    every_field do |type, value, viewable|
      # Sin permiso, `<view>` **levanta**, y eso es deliberado: pintar un hueco
      # donde hay algo que no se puede ver hace que la página mienta con
      # naturalidad. Lo que importa aquí es que levante siempre igual, sea del
      # tipo que sea, y no que unos tipos levanten y otros pinten.
      unless viewable
        assert_raises(HoboRapid::PermissionDenied, "#{type} deja ver lo que no se puede ver") do
          painted(:view, type, value, false)
        end
        next
      end

      html = paint_or_explain(:view, type, value)

      assert_kind_of String, html, "<view> de #{type} con #{value.inspect} no ha devuelto texto"
    end
  end

  def test_every_type_can_be_edited
    every_field do |type, value, viewable|
      html = paint_or_explain(:input, type, value)

      assert_kind_of String, html, "<input> de #{type} con #{value.inspect} no ha devuelto texto"
    end
  end

  # --- y lo que no puede pasar nunca ------------------------------------------------

  # Un campo que la persona no puede ver no llega a la página **de ninguna
  # forma**: ni pintado ni dentro del mensaje del error. El permiso es del
  # modelo y no de la vista (pieza 4), y si un solo tipo se escapa la fuga es
  # del tamaño de una columna entera.
  def test_a_field_nobody_may_see_never_reaches_the_page
    VALUES.each do |type, values|
      values.each do |value|
        error = assert_raises(HoboRapid::PermissionDenied) { painted(:view, type, value, false) }

        # El vacío no cuenta: está dentro de cualquier texto y la comprobación
        # sería cierta siempre, que es peor que no hacerla.
        next if value.to_s.empty?

        refute_includes error.message, value.to_s,
                        "el error de permiso de #{type} lleva dentro el valor"
      end
    end
  end

  # Una contraseña no sale escrita en el html ni pintándola ni editándola. Es el
  # tipo con el que un fallo no es feo, es una filtración.
  def test_a_password_never_reaches_the_page
    secret = VALUES["password"].first

    %i[view input].each do |tag|
      html = paint_or_explain(tag, "password", secret)

      refute_includes html, secret, "<#{tag}> ha escrito la contraseña en la pagina"
    end
  end

  # Un control sin `name` no llega a Rails: lo que la persona escriba se pierde
  # sin decir nada.
  def test_every_control_has_a_name
    VALUES.each_key do |type|
      html = paint_or_explain(:input, type, VALUES[type].first)
      next if html.strip.empty?

      assert_match(/name="[^"]+"/, html, "el <input> de #{type} no tiene name: lo que se escriba no llega")
    end
  end

  # Lo que viene del usuario se escapa. `<script>` en un campo de texto tiene que
  # salir como texto, no como una etiqueta -- salvo en los tipos que **son**
  # html, que existen justo para eso.
  def test_what_the_user_wrote_is_escaped
    attack = "<script>alert(1)</script>"

    html = painted(:view, "string", attack, true)

    refute_includes html, "<script>", "un string se ha pintado como html"
    assert_includes html, "&lt;script&gt;"
  end

  # Y la lista de tipos no se queda atrás: un tipo nuevo en HoboFields sin su
  # fila aquí es un tipo que nadie prueba.
  def test_no_type_is_left_untested
    faltan = HoboFields.field_types.keys.map(&:to_s) - VALUES.keys

    assert_empty faltan, "tipos sin probar: #{faltan.join(', ')}"
  end

end
