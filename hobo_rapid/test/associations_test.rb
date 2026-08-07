require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../dryml/lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../hobo_support/lib", __dir__)
require "rapid/param_contract"
require "hobo_rapid/tags/associations"

# The inputs that ask the database what the options are. This is where "the form
# builds itself" stops being a slogan: <input:author/> on a belongs_to becomes a
# select of the authors this user may see.
class AssociationsTest < Minitest::Test
  include ParamContract::Assertions

  Author = Struct.new(:id, :name, :visible) do
    def viewable_by?(_user) = visible
  end

  # Stands in for an ActiveRecord class and its reflection.
  class AuthorScope
    def initialize(records) = @records = records
    def limit(n) = AuthorScope.new(@records.first(n))
    def select(&block) = @records.select(&block)
    def to_a = @records
  end

  Reflection = Struct.new(:klass, :foreign_key, :macro)

  class Story
    attr_accessor :author, :tags

    AUTHORS = [Author.new(1, "Tom", true), Author.new(2, "Imanol", true), Author.new(3, "Oculto", false)].freeze

    def self.reflections
      { "author" => Reflection.new(AuthorScope.new(AUTHORS), "author_id", :belongs_to),
        "tags" => Reflection.new(AuthorScope.new(AUTHORS), "story_id", :has_many) }
    end

    def self.attr_type(_field) = nil
    def editable_by?(_user, _field = nil) = true
    def viewable_by?(_user, _field = nil) = true
  end

  def story = @story ||= Story.new

  def painted(tag_name, field, **attributes)
    outer = Rapid::Tag.new
    Rapid::Context.capture { outer.with_field(field, story) { outer.call_tag(tag_name, attributes) } }
  end

  # --- select-one -------------------------------------------------------------

  def test_a_belongs_to_becomes_a_select_of_the_records
    html = painted(:select_one, :author)

    assert_includes html, "<select"
    assert_includes html, ">Tom<"
    assert_includes html, ">Imanol<"
  end

  # The permission check is not decoration: a record the user may not see must
  # not appear in a list of things to choose.
  def test_a_record_the_user_may_not_see_is_not_offered
    refute_includes painted(:select_one, :author), "Oculto"
  end

  def test_the_name_is_the_foreign_key
    assert_includes painted(:select_one, :author), %(name="story[author_id]")
  end

  def test_the_chosen_record_comes_out_selected
    story.author = Story::AUTHORS[1]

    html = painted(:select_one, :author)
    assert_match(/<option value="2" selected>Imanol/, html)
  end

  # A select with no empty option quietly picks the first record for you.
  def test_nothing_chosen_yet_means_a_blank_option
    assert_includes painted(:select_one, :author), %(<option value="">)
  end

  def test_the_blank_option_can_be_refused
    refute_includes painted(:select_one, :author, :include_none => false), %(<option value="">)
  end

  def test_a_field_that_may_not_be_edited_is_refused
    Story.define_method(:editable_by?) { |_user, _field = nil| false }

    assert_raises(HoboRapid::PermissionDenied) { painted(:select_one, :author) }
  ensure
    Story.define_method(:editable_by?) { |_user, _field = nil| true }
  end

  # --- check-many -------------------------------------------------------------

  def test_a_has_many_becomes_tick_boxes
    story.tags = [Story::AUTHORS[0]]

    html = painted(:check_many, :tags)
    assert_includes html, %(type="checkbox")
    assert_match(/value="1"[^>]* checked/, html)
    refute_match(/value="2"[^>]* checked/, html)
  end

  # Without the hidden field, unticking everything sends nothing at all and the
  # collection is never emptied.
  def test_unticking_everything_is_heard
    html = painted(:check_many, :tags)

    assert_includes html, %(<input type="hidden" name="story[tags][]" value="">)
  end

  # --- the contract -----------------------------------------------------------

  def test_every_param_of_check_many_is_overridable
    assert_every_param_overridable(:check_many, { :name => "sin registro", :this => [] })
  end

  # --- <input> knows an association when it sees one ---------------------------
  #
  # Which control an association wants is decided by the *shape* of the
  # association, not by the class of the value: `movie.category` is a Category,
  # and that says nothing about there being a Genre to pick as well. So the
  # decision lives in <input>, and not in <input-content>, which dispatches on
  # the class. Without it a belongs_to got the fallback control -- a text box
  # for a record -- and Hobo's oldest promise, a form that builds itself from
  # the model, quietly stopped being true for every association.

  def test_input_on_a_belongs_to_gives_a_select
    html = painted(:input, :author)

    assert_includes html, "<select"
    assert_includes html, %(name="story[author_id]")
    assert_includes html, ">Tom<"
  end

  def test_input_on_a_has_many_gives_tick_boxes
    story.tags = []
    html = painted(:input, :tags)

    assert_includes html, %(type="checkbox")
    assert_includes html, ">Tom<"
  end

end
