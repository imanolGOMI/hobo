require "test_helper"
require "hobo_rapid/params"

# The seven verbs a view retouches a derived page with -- DRYML's params written
# in ERB (hobo_rapid/params.rb).
#
# The verbs only declare: what they leave behind is a hash of `Rapid::Parameter`
# that the page is painted with. So every test here declares on a stand-in for a
# view, then paints a tag with what was declared, and looks at the html. That is
# the whole path a page goes through, minus Rails.
class ParamsTest < Minitest::Test

  # A view, as far as the verbs are concerned: something that holds what was
  # declared and can capture a block. Rails brings both; outside Rails, this is
  # what they amount to.
  class View
    include HoboRapid::Params
  end

  def setup
    @view = View.new
    Rapid.define(:params_test_panel) do
      tag("div", { :class => "panel" }) do
        tag("h2", {}, :heading) { text "Books" }
        tag("p", {}, :body) { text "eight of them" }
      end
    end
  end

  def declared = @view.instance_variable_get(:@hobo_declared_params) || {}
  def painted = Rapid.render(:params_test_panel, {}, **declared)

  # --- the four insertion points ---------------------------------------------

  def test_append_puts_the_content_at_the_end_of_what_was_there
    @view.append_heading " — the library"

    assert_includes painted, "<h2>Books — the library</h2>"
  end

  def test_prepend_puts_it_at_the_start
    @view.prepend_heading "All "

    assert_includes painted, "<h2>All Books</h2>"
  end

  def test_before_and_after_go_outside_the_element
    @view.before_heading "<hr>"
    @view.after_heading "<hr>"

    assert_includes painted, "&lt;hr&gt;<h2>Books</h2>&lt;hr&gt;"
  end

  # The one thing Hobo 2 documented as impossible: `before` and `after` on the
  # same param at once. Here both are ordinary params, so there is nothing to
  # collide.
  def test_before_and_after_may_be_used_together
    @view.before_heading "one"
    @view.after_heading "two"

    html = painted
    assert_includes html, "one<h2>"
    assert_includes html, "</h2>two"
  end

  # --- the content, the attributes, the whole element ------------------------

  def test_param_replaces_the_content
    @view.param :heading, "Novels"

    assert_includes painted, "<h2>Novels</h2>"
  end

  def test_param_with_attributes_only_keeps_the_content
    @view.param :heading, :class => "big"

    assert_includes painted, %(<h2 class="big">Books</h2>)
  end

  def test_replace_takes_the_element_away_as_well
    @view.replace :heading, "<b>Novels</b>"

    html = painted
    refute_includes html, "<h2>"
    assert_includes html, "&lt;b&gt;Novels&lt;/b&gt;"
  end

  def test_without_takes_the_extension_point_away
    @view.without :heading

    html = painted
    refute_includes html, "<h2>"
    assert_includes html, "<p>eight of them</p>"
  end

  # --- what was going to be painted there ------------------------------------

  def test_param_content_inside_a_param_is_the_content_that_was_there
    @view.param :heading do
      "<a href=\"/books\">#{@view.param_content}</a>"
    end

    assert_includes painted, %(<h2><a href="/books">Books</a></h2>)
  end

  # And inside a `replace` it is the **whole element**, because that is what was
  # taken away. DRYML called it `<x: restore/>` and it is the difference between
  # wrapping the title and wrapping the heading.
  def test_param_content_inside_a_replace_is_the_whole_element
    @view.replace :heading do
      "<a href=\"/books\">#{@view.param_content}</a>"
    end

    assert_includes painted, %(<a href="/books"><h2>Books</h2></a>)
  end

  def test_param_content_outside_a_param_is_empty_rather_than_an_error
    assert_equal "", @view.param_content
  end

  # --- what is not a verb -----------------------------------------------------

  # A bare name cannot be a param: it would turn every typo into a param that
  # does not exist and does not complain. Only the four prefixes are recognised.
  def test_a_name_that_is_not_an_insertion_point_is_not_swallowed
    error = assert_raises(NoMethodError) { @view.heading "Novels" }

    assert_match(/heading/, error.message)
  end

  def test_respond_to_knows_the_insertion_points_and_nothing_else
    assert_respond_to @view, :append_heading
    assert_respond_to @view, :before_anything_at_all
    refute_respond_to @view, :heading
  end

  # --- strings are escaped, blocks are markup --------------------------------

  def test_a_string_is_escaped
    @view.param :heading, "Books & Co"

    assert_includes painted, "<h2>Books &amp; Co</h2>"
  end

  def test_a_block_is_markup
    @view.param(:heading) { "<b>Books</b>" }

    assert_includes painted, "<h2><b>Books</b></h2>"
  end

  # The block is kept unrun. Running it at declaration time would be simpler and
  # would break `param_content`, whose answer only exists while the tag paints.
  def test_the_block_runs_when_the_page_is_painted_and_not_before
    ran = false
    @view.param(:heading) { ran = true; "x" }

    refute ran, "the block ran while it was being declared"
    painted
    assert ran
  end

end
