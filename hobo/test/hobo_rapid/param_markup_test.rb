require "test_helper"
require "hobo_rapid/param_markup"

# The params of DRYML written as markup, in any template language.
#
# What is checked here is the rewriting, one construction at a time, and -- more
# than that -- **what it leaves alone**. This pass runs over every template of
# every application, including the ones Rails and other gems ship, so a false
# positive is not a bug in a corner: it is a template of somebody else's turned
# into Ruby that does not run.
class ParamMarkupTest < Minitest::Test

  def rewrite(source) = HoboRapid::ParamMarkup.transform(source)

  # --- the four insertion points -----------------------------------------------

  def test_append
    assert_equal "<% append_heading do %>hola<% end %>",
                 rewrite("<append-heading:>hola</append-heading:>")
  end

  def test_before_prepend_and_after
    %w[before prepend after].each do |which|
      assert_equal "<% #{which}_body do %>x<% end %>",
                   rewrite("<#{which}-body:>x</#{which}-body:>")
    end
  end

  # What is inside a param is left exactly as it was, which is the point of
  # rewriting only the tags: it is still ERB, or Slim, or whatever it was.
  def test_the_content_is_untouched
    assert_equal %(<% append_heading do %><%= " — La Biblioteca" %><% end %>),
                 rewrite(%(<append-heading:><%= " — La Biblioteca" %></append-heading:>))
  end

  # --- the param itself ---------------------------------------------------------

  def test_filling_a_param
    assert_equal "<% param :heading do %>Mis libros<% end %>",
                 rewrite("<heading:>Mis libros</heading:>")
  end

  def test_attributes
    assert_equal %(<% param :heading, :class => "big" %>),
                 rewrite(%(<heading: class="big"/>))
  end

  def test_a_ruby_attribute
    assert_equal %(<% param :heading, :class => (thing.name) %>),
                 rewrite(%(<heading: class="&thing.name"/>))
  end

  def test_replace
    assert_equal "<% replace :heading do %>otra cosa<% end %>",
                 rewrite("<heading: replace>otra cosa</heading:>")
  end

  def test_a_hyphenated_param_name
    assert_equal "<% param :content_body do %>x<% end %>",
                 rewrite("<content-body:>x</content-body:>")
  end

  # --- and now what it must not touch -------------------------------------------

  def test_plain_html_is_untouched
    source = %(<div class="x"><p>hola</p><br><img src="/a.png"></div>)

    assert_equal source, rewrite(source)
  end

  def test_erb_is_untouched
    source = "<% if x %><%= render \"a\" %><% end %>"

    assert_equal source, rewrite(source)
  end

  # `<svg:rect>` and `<xsl:template>` have a **name** after the colon, and a
  # param has nothing. That is the whole rule, and it is what makes this safe to
  # run over a template nobody wrote for Hobo.
  def test_an_xml_namespace_is_not_a_param
    source = %(<svg:rect width="10"/><xsl:template match="x"></xsl:template>)

    assert_equal source, rewrite(source)
  end

  def test_a_colon_in_text_is_not_a_param
    source = "<p>Hora: 12:30</p><a href=\"http://x\">x</a>"

    assert_equal source, rewrite(source)
  end

  # A ternary in an attribute has a colon in it and is not markup at all.
  def test_a_colon_inside_ruby_is_untouched
    source = %(<%= tag.div class: (a ? "x" : "y") %>)

    assert_equal source, rewrite(source)
  end

  def test_a_file_with_no_markup_is_returned_as_it_is
    source = "solo texto, sin una etiqueta"

    assert_same source, rewrite(source)
  end

  # --- las llamadas a tags ------------------------------------------------------

  def test_a_hyphenated_name_hobo_knows_becomes_a_call
    Rapid.define(:probe_widget) { text "x" }

    assert_equal "<%= probe_widget %>", rewrite("<probe-widget/>")
  end

  def test_with_attributes
    Rapid.define(:probe_widget) { text "x" }

    assert_equal %(<%= probe_widget(:fields => "a, b") %>),
                 rewrite(%(<probe-widget fields="a, b"/>))
  end

  def test_an_open_tag_takes_a_block
    Rapid.define(:probe_widget) { text "x" }

    assert_equal "<%= probe_widget do %>dentro<% end %>",
                 rewrite("<probe-widget>dentro</probe-widget>")
  end

  # Un componente web lleva guion igual que un tag, y es un elemento de verdad
  # que el navegador respeta. Sin este limite, cualquier aplicacion que use uno
  # se rompe.
  def test_a_hyphenated_name_hobo_does_not_know_is_left_alone
    source = %(<ion-button color="primary">Pulsa</ion-button>)

    assert_equal source, rewrite(source)
  end

  # Sin guion no se toca: `<card>` no se puede distinguir de un elemento que
  # nadie conoce, y una plantilla que lo escriba pensando en html no debe
  # empezar a llamar a un tag.
  def test_a_name_with_no_hyphen_is_left_alone
    Rapid.define(:card) { text "x" }

    assert_equal "<card>x</card>", rewrite("<card>x</card>")
  end

end
