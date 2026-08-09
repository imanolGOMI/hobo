require "test_helper"
require "rapid/param_contract"
require "hobo_rapid/derivation"

# Piece 10: you declare a model and the pages exist.
#
# No file is generated. The tags are defined by running Ruby over what the model
# already said -- which is the whole benefit of tags being Ruby objects.
class DerivationTest < Minitest::Test
  include ParamContract::Assertions

  class Task
    attr_accessor :id, :title, :done
    # Buildable with no arguments, because <input-many> paints its template row
    # from a blank one -- an empty collection has to be able to grow.
    def initialize(id = nil, title = nil, done = nil) = (@id, @title, @done = id, title, done)
    def self.field_specs = { :title => nil, :done => nil }
    def self.name_attribute = :title
    def self.attr_type(field) = { "title" => String, "done" => Rapid::Boolean }[field.to_s]
    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = true
  end

  class Story
    attr_accessor :id, :title, :body, :published_on, :tasks

    def self.field_specs = { :title => nil, :body => nil, :published_on => nil, :tasks => nil }
    def self.name_attribute = :title
    def self.attr_type(field)
      { "title" => String, "body" => String, "published_on" => Date, "tasks" => Array }[field.to_s]
    end
    def self.view_hints = self
    def self.children = [:tasks]
    def self.human_attribute_name(field) = field.to_s.humanize
    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = true
  end

  def story
    @story ||= Story.new.tap do |s|
      s.id = 1
      s.title = "Primera historia"
      s.body = "El cuerpo"
      s.published_on = Date.new(2026, 8, 7)
      s.tasks = [Task.new(1, "Una tarea", true)]
    end
  end

  def setup
    HoboRapid::Derivation.derive(Story)
    HoboRapid::Derivation.derive(Task)
  end

  # A collection knows what it holds -- that is how an index of stories knows to
  # paint story cards. An ActiveRecord relation answers this; here it is a double.
  class Collection < Array
    def member_class = Story
  end

  def collection_of(records) = Collection.new(records)

  def render(tag_name, this)
    Rapid.render(tag_name, {}, :this => this)
  end

  # --- what the engine reads out of the model ---------------------------------

  def test_it_finds_the_name_attribute
    assert_equal "title", HoboRapid::Derivation.name_attribute_of(Story)
  end

  # The summary is everything but the name (that is the heading) and the
  # children (those are collections, not summary material).
  def test_the_summary_leaves_out_the_name_and_the_children
    assert_equal %w[body published_on], HoboRapid::Derivation.summary_fields(Story)
  end

  # --- the card ---------------------------------------------------------------

  def test_a_card_shows_the_name_as_its_heading
    html = render(:card, story)

    assert_includes html, "<h3>"
    assert_includes html, "Primera historia"
  end

  # Housekeeping columns are never what a page is about: a card that leads with
  # "Created at" is a card about the database.
  def test_a_card_leaves_out_the_timestamps
    refute_includes HoboRapid::Derivation.summary_fields(Story), "created_at"
    refute_includes HoboRapid::Derivation.summary_fields(Story), "updated_at"
  end

  def test_a_card_lists_the_other_fields_with_their_labels
    html = render(:card, story)

    assert_includes html, "El cuerpo"
    assert_includes html, "<dt>Published on</dt>"
  end

  # --- the show page ----------------------------------------------------------

  # "Story <name>", in a header panel -- the shape Hobo 2 painted, so two
  # applications built the same way look the same.
  def test_a_show_page_leads_with_the_model_and_the_name
    html = render(:show_page, story)

    assert_includes html, "<h2>Story "
    assert_includes html, "Primera historia"
    assert_includes html, %(class="content-header)
  end

  # The type decides how each field is painted, all the way down.
  def test_a_date_field_paints_as_a_date
    assert_includes render(:show_page, story), "2026-08-07"
  end

  def test_the_children_get_a_section_of_their_own
    html = render(:show_page, story)

    assert_includes html, %(<section class="collection-section tasks">)
    assert_includes html, "<h3>Tasks</h3>"
    assert_includes html, "Una tarea"
  end

  # --- the index page ---------------------------------------------------------

  # A table, not a list of cards: that is what hobo_bootstrap painted, and cards
  # were hobo_clean's style. `<card>` is still there for anybody who wants it.
  def test_an_index_paints_a_row_for_each_record
    other = Story.new
    other.id = 2
    other.title = "Segunda"
    other.tasks = []

    html = render(:index_page, collection_of([story, other]))

    assert_includes html, %(<table class="collection-table">)
    assert_includes html, "<th>Body</th>"
    assert_equal 2, html.scan("<tr>").length - 1, "una fila por registro, mas la de cabeceras"
    assert_includes html, "Primera historia"
    assert_includes html, "Segunda"
  end

  # A list you can look at and not use is not a list. The old theme painted an
  # actions column on every row and a "New X" above the table.
  def test_an_index_offers_the_actions
    html = render(:index_page, collection_of([story]))

    assert_includes html, %(<th class="actions">Actions</th>)
    assert_includes html, %(<td class="actions">)
  end

  def test_an_empty_index_says_so
    assert_includes render(:index_page, collection_of([])), "Nothing here yet"
  end

  # --- what a model is called ---------------------------------------------------
  #
  # The heading of an index used to be `model.name.humanize` and nothing else, so
  # a page said "Stories" whatever language the application was in -- while the
  # column headings above the same table were translated, because those go
  # through `human_attribute_name`. `activerecord.models.story`, the key every
  # Rails application knows, had no effect on any page Hobo painted.
  #
  # And the second half matters more: **deriving happens once, rendering happens
  # on every request**. The language belongs to the request, so a name captured
  # while deriving is the language the server started in, for ever.
  class Named
    attr_accessor :id, :name
    def self.field_specs = { :name => nil }
    def self.name_attribute = :name
    def self.attr_type(_field) = String
    def self.name = "Story"
    def viewable_by?(_user, _field = nil) = true

    # What Rails answers. `model_name.human` reads `activerecord.models.story`,
    # and here it reads whatever the test last said.
    def self.said = @said ||= { :one => "Story", :other => "Stories" }
    def self.model_name = ModelName.new(said)

    class ModelName
      def initialize(said) = @said = said
      def human(options = {}) = options[:count].to_i == 2 ? @said[:other] : @said[:one]
    end
  end

  class NamedCollection < Array
    def member_class = Named
  end

  def test_the_heading_is_what_rails_calls_the_model
    Named.said.merge!(:one => "Relato", :other => "Relatos")
    HoboRapid::Derivation.derive(Named)

    html = Rapid.render(:index_page, {}, :this => NamedCollection.new([]))

    assert_includes html, "<h2>Relatos</h2>"
  ensure
    Named.said.merge!(:one => "Story", :other => "Stories")
  end

  # The one that would have caught it: derive first, translate afterwards.
  def test_the_name_is_asked_when_the_page_is_painted_not_when_it_is_derived
    HoboRapid::Derivation.derive(Named)
    Named.said.merge!(:one => "Relato", :other => "Relatos")

    html = Rapid.render(:index_page, {}, :this => NamedCollection.new([]))

    assert_includes html, "<h2>Relatos</h2>",
                    "el idioma es de cada peticion, no del arranque del servidor"
  ensure
    Named.said.merge!(:one => "Story", :other => "Stories")
  end

  # --- offering to create -------------------------------------------------------
  #
  # The index offered "New story" to anybody the moment the route existed, and a
  # stranger who followed it got a form with every input read-only: the
  # permissions were right and the link was not. **An offer is a promise**, and
  # this is the model being asked whether it can be kept.
  #
  # Nothing could catch this before: with no Rails there is no route, so the
  # link was never painted in a test at all. It took looking at a real
  # application as a guest.
  class Thing
    attr_accessor :id, :name
    def self.field_specs = { :name => nil }
    def self.name_attribute = :name
    def self.attr_type(_field) = String
    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = false
    def destroyable_by?(_user) = false
    def creatable_by?(_user) = false
  end

  class OpenThing < Thing
    def creatable_by?(_user) = true
  end

  class ThingCollection < Array
    def initialize(member_class, records) = (@member_class = member_class; super(records))
    attr_reader :member_class
  end

  # There is no Rails here, so no route -- which is exactly why the link never
  # showed up in a test. Say there is one.
  def with_a_new_route
    Rapid::Tag.class_eval do
      alias_method :new_path_for_without_stub, :new_path_for
      define_method(:new_path_for) { |_model| "/things/new" }
    end
    yield
  ensure
    Rapid::Tag.class_eval do
      alias_method :new_path_for, :new_path_for_without_stub
      remove_method :new_path_for_without_stub
    end
  end

  def index_of(model)
    HoboRapid::Derivation.derive(model)
    with_a_new_route { Rapid.render(:index_page, {}, :this => ThingCollection.new(model, [])) }
  end

  def test_the_index_does_not_offer_a_new_one_to_whoever_cannot_make_one
    refute_includes index_of(Thing), "/things/new"
  end

  def test_and_offers_it_to_whoever_can
    assert_includes index_of(OpenThing), "/things/new"
  end

  # --- the form ---------------------------------------------------------------

  # Where `fields do` pays off: nobody said what control each field gets.
  def test_the_form_gives_each_field_the_control_its_type_asks_for
    html = render(:model_form, story)

    assert_includes html, %(name="story[title]")
    assert_includes html, %(type="date")
    assert_includes html, %(value="2026-08-07")
  end

  def test_the_form_labels_every_field
    html = render(:model_form, story)

    assert_includes html, "<label>Title</label>"
    assert_includes html, "<label>Body</label>"
  end

  # --- the contract -----------------------------------------------------------
  #
  # A derived tag is still a tag: a theme has to be able to get inside it.

  def test_every_param_of_a_derived_card_is_overridable
    assert_every_param_overridable(:card, { :name => "una historia", :this => story })
  end

  def test_every_param_of_a_derived_show_page_is_overridable
    assert_every_param_overridable(:show_page, { :name => "una historia", :this => story })
  end

  def test_every_param_of_a_derived_form_is_overridable
    assert_every_param_overridable(:model_form, { :name => "una historia", :this => story })
  end

  # --- an association is not a number -------------------------------------------
  #
  # `category_id` is what the database keeps; `category` is what the page is
  # about. The model already said which is which -- `belongs_to :category` names
  # the foreign key -- and until the engine read that, every belongs_to came out
  # as the id: on the index, on the record page and in the form, where it got a
  # number box instead of a select.

  class Category
    attr_accessor :id, :name
    def initialize(id, name) = (@id, @name = id, name)
    def self.name_attribute = :name
    def viewable_by?(_user, _field = nil) = true
  end

  Reflection = Struct.new(:macro, :name, :foreign_key, :klass, :options)

  class Film
    attr_accessor :id, :title, :category

    def self.field_specs = { :title => nil, :category_id => nil }
    def self.name_attribute = :title
    def self.attr_type(field) = { "title" => String }[field.to_s]
    def self.human_attribute_name(field) = field.to_s.humanize
    def self.reflections
      { "category" => Reflection.new(:belongs_to, :category, "category_id", nil, {}) }
    end
    def viewable_by?(_user, _field = nil) = true
    def editable_by?(_user, _field = nil) = true
  end

  def test_a_foreign_key_is_derived_as_its_association
    fields = HoboRapid::Derivation.summary_fields(Film)

    assert_includes fields, "category"
    refute_includes fields, "category_id"
  end

  # A polymorphic belongs_to has no single class to ask for choices, so it is
  # left as it is rather than blowing up at render time.
  def test_a_polymorphic_belongs_to_is_left_alone
    reflection = Reflection.new(:belongs_to, :owner, "owner_id", nil, { :polymorphic => true })

    assert_nil HoboRapid::Derivation.belongs_to_name(polymorphic_model(reflection), "owner_id")
  end

  def polymorphic_model(reflection)
    Class.new do
      define_singleton_method(:reflections) { { "owner" => reflection } }
    end
  end

  # --- the children are part of the form ---------------------------------------
  #
  # A collection you can only fill in from another page is not a nested form,
  # and creating one record from inside another is the thing Hobo was known for.
  # The children were derived into the card and the record page and left out of
  # the form, so `movie_genres` had nowhere to be typed.

  def test_the_form_offers_the_children_as_a_list_you_can_grow
    html = render(:model_form, story)

    assert_includes html, %(data-controller="rapid-input-many")
    assert_includes html, %(data-rapid-input-many-prefix-value="story[tasks]")
    assert_includes html, %(data-rapid-input-many-target="template")
    assert_includes html, %(name="story[tasks][0][done]")
  end

end
