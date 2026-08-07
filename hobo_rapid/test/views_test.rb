require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../dryml/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)
require "hobo_rapid/tags/views"

# Piece 9: <view> decides how to paint a value from its **type**, which is what
# `<view:body/>` means -- not "paint the body like this" but "paint this field,
# and the type knows how".
class ViewsTest < Minitest::Test

  # A model as `fields do` leaves it: it knows the declared type of each field,
  # which is what lets a blank field still paint as what it is.
  class Story
    attr_accessor :title, :published_on, :featured, :views_count, :secret

    TYPES = { "title" => String, "published_on" => Date, "featured" => Rapid::Boolean,
              "views_count" => Integer, "secret" => String }.freeze

    def self.attr_type(field) = TYPES[field.to_s]

    def viewable_by?(_user, field = nil) = field.to_s != "secret"
  end

  def story
    @story ||= Story.new.tap do |s|
      s.title = "Hola"
      s.published_on = Date.new(2026, 8, 7)
      s.featured = true
      s.views_count = 42
    end
  end

  def view_of(field, **attributes)
    outer = Rapid::Tag.new
    Rapid::Context.capture do
      outer.with_field(field, story) { outer.call_tag(:view, attributes) }
    end
  end

  # --- the type decides -------------------------------------------------------

  def test_a_string_paints_itself
    assert_includes view_of(:title), "Hola"
  end

  # And the type view goes *inside* the wrapper: they are two tags on purpose.
  def test_a_date_paints_as_a_date_inside_its_wrapper
    assert_equal %(<span class="view story-published-on">2026-08-07</span>), view_of(:published_on)
  end

  def test_a_number_paints_as_a_number
    assert_includes view_of(:views_count), "42"
  end

  def test_a_boolean_paints_a_tick
    assert_includes view_of(:featured), "&#10004;"
    assert_includes view_of(:featured), %(class="view story-featured")
  end

  # --- the wrapper ------------------------------------------------------------

  def test_the_wrapper_carries_the_type_and_field_as_a_class
    assert_includes view_of(:title), %(class="view story-title")
  end

  def test_no_wrapper_paints_the_value_bare
    assert_equal "Hola", view_of(:title, :no_wrapper => true)
  end

  def test_block_asks_for_a_div
    assert_includes view_of(:title, :block => true), "<div"
  end

  # --- blank values -----------------------------------------------------------

  # The point of dispatching on the *declared* type: a blank date is still a
  # date, and the page keeps its shape.
  def test_a_blank_field_still_paints_its_wrapper
    story.published_on = nil

    assert_includes view_of(:published_on), %(class="view story-published-on")
  end

  def test_if_blank_puts_something_in_its_place
    story.title = ""

    assert_includes view_of(:title, :if_blank => "sin titulo"), "sin titulo"
  end

  # --- permission -------------------------------------------------------------

  def test_a_field_that_may_not_be_viewed_is_refused
    assert_raises(HoboRapid::PermissionDenied) { view_of(:secret) }
  end

  def test_force_paints_it_anyway
    assert_includes view_of(:secret, :force => true), "view"
  end

end
