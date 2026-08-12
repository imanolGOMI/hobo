require "test_helper"
require "rapid/param_contract"
require "hobo_rapid/tags/page"

# Piece 13b: `<page>` is the contract between Hobo and a theme, and PLAN.md asks
# for it **with a test**. This is that test.
#
# It matters more than it looks. A theme is useful exactly to the extent that an
# application can change one corner of a page without owning the whole thing --
# and the first attempt (HALLAZGOS.md) died of params going missing one at a
# time. The sweep of layer 3 is what makes that impossible to do quietly.
class PageContractTest < Minitest::Test
  include ParamContract::Assertions

  SCENARIOS = [
    { :name => "una pagina normal", :attributes => { :title => "Historias" } },
    { :name => "con columna lateral", :attributes => { :title => "Historias" },
      :params => { :aside => Rapid.markup { text "algo al lado" } } },
    { :name => "con la navegacion abajo", :attributes => { :title => "Historias", :nav_location => "sub" } },
    { :name => "con el javascript al final",
      :attributes => { :title => "Historias", :bottom_load_javascript => true } },
  ].freeze

  # The whole contract, in one line. Every extension point the page declares --
  # in every shape it can take -- has to be reachable from outside.
  def test_every_extension_point_of_the_page_is_reachable
    assert_every_param_overridable(:page, SCENARIOS)
  end

  def painted(**attributes)
    params = attributes.delete(:params) || {}
    Rapid.render(:page, attributes, **params)
  end

  # --- the shape of a page ----------------------------------------------------

  def test_the_title_is_the_page_title_and_the_application_name
    assert_includes painted(:title => "Historias"), "<title>Historias : Hobo</title>"
  end

  def test_a_full_title_given_by_hand_wins
    assert_includes painted(:title => "Historias", :full_title => "Otra cosa"), "<title>Otra cosa</title>"
  end

  # `<nav>`, `<header>`, `<footer>` and `<aside>` are real elements now. The old
  # theme painted `<div class="navbar">` because it predates HTML5.
  def test_the_page_uses_the_html5_elements
    html = painted(:title => "x")

    assert_includes html, "<nav class=\"navbar"
    assert_includes html, %(<footer class="page-footer">)
  end

  # --- the aside --------------------------------------------------------------
  #
  # The sizes are twelfths, as they always were. What changed is who spells
  # them: the page says `content-9`, a **role**, and a theme turns that into
  # whatever it calls nine twelfths (`col-9` in Bootstrap). Without a theme the
  # role is what comes out, and it is a perfectly good thing to write css for.

  def test_without_an_aside_the_content_takes_the_whole_width
    assert_includes painted(:title => "x"), %(class="content content-12")
  end

  def test_an_aside_makes_room_for_itself
    html = painted(:title => "x", :params => { :aside => Rapid.markup { text "al lado" } })

    assert_includes html, %(class="content content-9")
    assert_includes html, %(class="aside aside-3")
    assert_includes html, "al lado"
  end

  def test_the_sizes_can_be_said_by_hand
    html = painted(:title => "x", :content_size => 8,
                   :params => { :aside => Rapid.markup { text "al lado" } })

    assert_includes html, %(class="content content-8")
    assert_includes html, %(class="aside aside-4")
  end

  def test_the_aside_can_go_on_the_left
    html = painted(:title => "x", :aside_location => "left",
                   :params => { :aside => Rapid.markup { text "IZQUIERDA" } })

    assert_operator html.index("IZQUIERDA"), :<, html.index("content-9")
  end

  # --- the javascript ---------------------------------------------------------

  def test_the_javascript_goes_in_the_head_by_default
    html = painted(:title => "x")

    assert_operator html.index("application.js"), :<, html.index("</head>")
  end

  def test_it_can_be_asked_to_go_at_the_bottom
    html = painted(:title => "x", :bottom_load_javascript => true)

    assert_operator html.index("application.js"), :>, html.index("</head>")
  end

  # --- what a theme is for ----------------------------------------------------

  def test_an_application_can_replace_one_corner_without_owning_the_page
    html = Rapid.render(:page, { :title => "x" },
                        :footer => Rapid.parameter(:replace => true) { text "MI PIE" })

    assert_includes html, "MI PIE"
    refute_includes html, %(<footer class="page-footer">)
    # ...and the rest of the page is untouched.
    assert_includes html, "<title>x : Hobo</title>"
    assert_includes html, "navbar"
  end

  # `old` is what lets a theme *add* to a corner instead of replacing it, which
  # is the difference between stacking themes and fighting over them.
  def test_a_corner_can_be_added_to_instead_of_replaced
    html = Rapid.render(:page, { :title => "x" },
                        :content_body => Rapid.markup { tag("div", { :class => "wrap" }) { old } })

    # Con su clase de papel: el hueco se llama `content-body` en el html, para
    # que una hoja pueda apuntarle. Lo que esta prueba mira es que el `<div>`
    # entra **dentro** del hueco y no en lugar de el.
    assert_includes html, %(<section class="content-body"><div class="wrap"></div></section>)
  end

end
