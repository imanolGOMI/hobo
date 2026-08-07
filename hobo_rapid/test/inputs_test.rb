require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../dryml/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)
require "rapid/param_contract"
require "hobo_rapid/tags/inputs"

# The write half of piece 9: `<input:title/>` does not say what control to
# paint. The type says.
class InputsTest < Minitest::Test
  include ParamContract::Assertions

  class Story
    attr_accessor :title, :body, :published_on, :featured, :views_count, :rating, :locked

    TYPES = { "title" => String, "published_on" => Date, "featured" => Rapid::Boolean,
              "views_count" => Integer, "rating" => Float, "locked" => String }.freeze

    def self.attr_type(field) = TYPES[field.to_s]

    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, field = nil) = field.to_s != "locked"
  end

  def story
    @story ||= Story.new.tap do |s|
      s.title = "Hola"
      s.published_on = Date.new(2026, 8, 7)
      s.featured = true
      s.views_count = 42
      s.rating = 4.5
      s.locked = "no se toca"
    end
  end

  def input_for(field, **attributes)
    outer = Rapid::Tag.new
    Rapid::Context.capture { outer.with_field(field, story) { outer.call_tag(:input, attributes) } }
  end

  # --- the type chooses the control -------------------------------------------

  def test_a_string_gets_a_text_field
    assert_includes input_for(:title), %(type="text")
    assert_includes input_for(:title), %(value="Hola")
  end

  # 81 lines of day/month/year selects, replaced by a control the browser has
  # had since 2014.
  def test_a_date_gets_a_date_control
    assert_includes input_for(:published_on), %(type="date")
    assert_includes input_for(:published_on), %(value="2026-08-07")
  end

  def test_a_number_gets_a_number_control
    assert_includes input_for(:views_count), %(type="number")
    assert_includes input_for(:views_count), %(step="1")
  end

  def test_a_float_steps_by_anything
    assert_includes input_for(:rating), %(step="any")
  end

  # --- the name Rails reads back ----------------------------------------------

  def test_the_name_comes_from_the_record_and_the_field
    assert_includes input_for(:title), %(name="story[title]")
  end

  def test_a_name_given_by_hand_wins
    assert_includes input_for(:title, :name => "otro[nombre]"), %(name="otro[nombre]")
  end

  # --- the checkbox trick -----------------------------------------------------

  # Without the hidden field an unticked box sends nothing at all, and the model
  # never learns it was unticked.
  def test_a_boolean_carries_a_hidden_field_so_unticking_is_heard
    painted = input_for(:featured)

    assert_includes painted, %(type="hidden")
    assert_includes painted, %(value="0")
    assert_includes painted, %(type="checkbox")
    assert_includes painted, "checked"
  end

  def test_an_unticked_boolean_is_not_checked
    story.featured = false

    refute_includes input_for(:featured), "checked"
  end

  # --- permission -------------------------------------------------------------

  def test_a_field_that_may_not_be_edited_is_shown_read_only
    painted = input_for(:locked)

    assert_includes painted, "no se toca"
    refute_includes painted, "<input"
  end

  def test_no_edit_disable_paints_the_control_disabled
    painted = input_for(:locked, :no_edit => :disable)

    assert_includes painted, "<input"
    assert_includes painted, "disabled"
  end

  def test_no_edit_skip_paints_nothing
    assert_equal "", input_for(:locked, :no_edit => :skip)
  end

  def test_no_edit_ignore_does_not_even_ask
    assert_includes input_for(:locked, :no_edit => :ignore), %(type="text")
  end

  # --- the contract -----------------------------------------------------------

  def test_every_param_of_input_is_overridable
    assert_every_param_overridable(:input, { :name => "un valor suelto", :this => "hola" })
  end

end
