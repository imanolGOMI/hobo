require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../dryml/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)
require "rapid/param_contract"
require "hobo_rapid/tags/structure"

# Piece 13a: the tags that used to live in the Bootstrap theme and should never
# have. A flash message, a list of errors, the moves a record offers -- an
# application *has* those, whatever it looks like.
class StructureTest < Minitest::Test
  include ParamContract::Assertions

  Errors = Struct.new(:messages) do
    def empty? = messages.empty?
    def size = messages.size
    def to_a = messages
  end

  ModelName = Struct.new(:human)

  class Story
    attr_accessor :errors
    def initialize(messages = []) = @errors = Errors.new(messages)
    def self.model_name = ModelName.new("Historia")
    def viewable_by?(_user, _field = nil) = true
  end

  Transition = Struct.new(:name)

  class Lifecycle
    def initialize(names) = @names = names
    def available_transitions_for(_user) = @names.map { |n| Transition.new(n) }
  end

  class Article
    def initialize(names) = @names = names
    def lifecycle = Lifecycle.new(@names)
    def viewable_by?(_user, _field = nil) = true
  end

  def render(tag_name, this = nil, flash: {})
    Rapid::Tag.class_eval { define_method(:flash_messages) { flash } }
    Rapid.render(tag_name, {}, :this => this)
  ensure
    Rapid::Tag.class_eval { define_method(:flash_messages) { {} } }
  end

  # --- flash ------------------------------------------------------------------

  def test_a_flash_message_paints_what_the_application_left
    html = render(:flash_message, nil, :flash => { :notice => "Guardado" })

    assert_includes html, "Guardado"
    assert_includes html, %(class="flash flash-notice")
    assert_includes html, %(role="alert")
  end

  def test_no_message_means_nothing_painted
    assert_equal "", render(:flash_message, nil, :flash => {})
  end

  # The kinds are the application's, not a fixed list.
  def test_every_kind_the_application_left_is_painted
    html = render(:flash_messages, nil, :flash => { :notice => "Guardado", :error => "Ups" })

    assert_includes html, "Guardado"
    assert_includes html, "Ups"
    assert_includes html, "flash-error"
  end

  # --- errors -----------------------------------------------------------------

  def test_the_errors_of_a_record_are_listed
    html = render(:error_messages, Story.new(["El titulo no puede estar en blanco", "El cuerpo tampoco"]))

    assert_includes html, "2 errores impidieron guardar Historia"
    assert_includes html, "<li>El titulo no puede estar en blanco</li>"
  end

  def test_one_error_is_said_in_singular
    assert_includes render(:error_messages, Story.new(["Uno solo"])), "1 error impidio"
  end

  # A form should not carry an empty box about.
  def test_a_record_with_no_errors_paints_nothing
    assert_equal "", render(:error_messages, Story.new)
  end

  # --- transitions ------------------------------------------------------------

  # The buttons are not written anywhere: they are what the record can do right
  # now, for this user. That is what lifecycles are for.
  def test_the_buttons_are_the_moves_the_record_offers
    html = render(:transition_buttons, Article.new(%i[publish retract]))

    assert_includes html, "Publish"
    assert_includes html, "Retract"
    assert_includes html, "?transition=publish"
  end

  def test_a_record_with_no_moves_paints_nothing
    assert_equal "", render(:transition_buttons, Article.new([]))
  end

  # --- the contract -----------------------------------------------------------

  def test_every_param_of_the_error_messages_is_overridable
    assert_every_param_overridable(:error_messages, { :name => "con errores", :this => Story.new(["Uno"]) })
  end

  def test_every_param_of_the_transitions_is_overridable
    assert_every_param_overridable(:transition_buttons, { :name => "con transiciones", :this => Article.new(%i[publish]) })
  end

end
