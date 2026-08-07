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

  # --- <input-many>: la coleccion dentro del formulario de su duenyo -----------
  #
  # The tag and `rapid_input_many_controller.js` are two halves of one thing,
  # and what they agree on is a DOM. So these check the DOM, not the prose:
  # the targets the controller looks for, the prefix it renumbers from, and the
  # names Hobo's accessible associations read on the way back.

  Genre = Struct.new(:id, :name) do
    def viewable_by?(_user) = true
  end

  class GenreScope
    def initialize(records) = @records = records
    def limit(_n) = self
    def select(&block) = @records.select(&block)
  end

  ManyReflection = Struct.new(:klass, :foreign_key, :macro, :options, :name)

  class MovieGenre
    attr_accessor :id, :genre, :movie

    GENRES = [Genre.new(1, "Cine negro"), Genre.new(2, "Ciencia ficcion")].freeze

    def self.field_specs = { :genre_id => nil, :movie_id => nil }
    def self.name_attribute = nil
    def self.attr_type(_field) = nil
    def self.reflections
      { "genre" => ManyReflection.new(GenreScope.new(GENRES), "genre_id", :belongs_to, {}, :genre),
        "movie" => ManyReflection.new(Film, "movie_id", :belongs_to, {}, :movie) }
    end
    def editable_by?(_user, _field = nil) = true
    def viewable_by?(_user, _field = nil) = true
  end

  class Film
    attr_accessor :id, :movie_genres

    def self.name = "Film"
    def self.field_specs = { :movie_genres => nil }
    def self.reflections
      { "movie_genres" => ManyReflection.new(MovieGenre, "movie_id", :has_many, {}, :movie_genres) }
    end
    def self.attr_type(_field) = nil
    def editable_by?(_user, _field = nil) = true
    def viewable_by?(_user, _field = nil) = true
  end

  def film
    @film ||= Film.new.tap do |f|
      f.id = 7
      row = MovieGenre.new
      row.id = 3
      row.genre = MovieGenre::GENRES.first
      f.movie_genres = [row]
    end
  end

  def input_many_html
    outer = Rapid::Tag.new
    Rapid::Context.capture { outer.with_field(:movie_genres, film) { outer.call_tag(:input_many) } }
  end

  def test_it_speaks_the_dom_the_stimulus_controller_reads
    html = input_many_html

    assert_includes html, %(data-controller="rapid-input-many")
    assert_includes html, %(data-rapid-input-many-prefix-value="film[movie_genres]")
    assert_includes html, %(data-rapid-input-many-target="template")
    assert_includes html, %(data-rapid-input-many-target="item")
    assert_includes html, %(data-action="rapid-input-many#add")
    assert_includes html, %(data-action="rapid-input-many#remove")
  end

  # Without a template row an empty collection can never grow: there is nothing
  # to clone. It is painted from a blank record and hidden.
  def test_there_is_a_hidden_template_row_even_with_no_records
    film.movie_genres = []
    html = input_many_html

    assert_includes html, %(data-rapid-input-many-target="template")
    assert_includes html, %(name="film[movie_genres][-1][genre_id]")
  end

  # The names are Hobo's, not Rails': no `_attributes`, and a belongs_to travels
  # as its foreign key. That is what `:accessible => true` reads.
  def test_the_names_are_the_ones_accessible_associations_read
    html = input_many_html

    assert_includes html, %(name="film[movie_genres][0][genre_id]")
    refute_includes html, "_attributes"
  end

  # The id of an existing row travels with it, or the server cannot tell
  # "change this one" from "make another".
  def test_an_existing_row_carries_its_id
    assert_includes input_many_html, %(name="film[movie_genres][0][id]")
  end

  # Asking again which film a row belongs to would be asking the user to repeat
  # the page they are on.
  def test_the_way_back_to_the_owner_is_not_a_question
    refute_includes input_many_html, "movie_id"
  end

  # Removing every row has to *say* so: parameters that simply lack the key read
  # as "leave it alone", and the rows come back on the next page.
  def test_an_emptied_collection_can_say_it_is_empty
    html = input_many_html

    assert_includes html, %(data-rapid-input-many-target="empty")
    assert_includes html, %(name="film[movie_genres]")
  end

  # The param sweep of <input-many> lives in derivation_test, not here: a
  # scenario only carries `this`, and an <input-many> with no owner has no
  # prefix, no member class and nothing to paint. Where it is really used is
  # inside a derived form, and that is where it is swept.

  # --- <select-one-or-new>: elegir uno, o hacerlo aqui mismo -------------------
  #
  # The thing Hobo was known for in a form. Hobo 2 did it with a modal and told
  # you, in its own documentation, to patch the controller's `create` action and
  # inject JavaScript afterwards. Here the new record's fields ride in the
  # parent form and `:accessible => true` creates it on save -- so the server
  # side is the one that already works, and what is left is naming things right.

  class Style
    attr_accessor :id, :name
    def self.field_specs = { :name => nil }
    def self.name_attribute = :name
    def self.attr_type(field) = { "name" => String }[field.to_s]
    def self.human_attribute_name(field) = field.to_s.humanize
    def self.limit(_n) = self
    def self.select(&block) = [].select(&block)
    def self.name = "Style"
    def editable_by?(_user, _field = nil) = true
    def viewable_by?(_user, _field = nil) = true
  end

  StyleReflection = Struct.new(:klass, :foreign_key, :macro, :options, :name)

  class Track
    attr_accessor :style, :plain_style

    def self.name = "Track"
    def self.reflections
      { "style" => StyleReflection.new(Style, "style_id", :belongs_to, { :accessible => true }, :style),
        "plain_style" => StyleReflection.new(Style, "plain_style_id", :belongs_to, {}, :plain_style) }
    end
    def self.attr_type(_field) = nil
    def editable_by?(_user, _field = nil) = true
    def viewable_by?(_user, _field = nil) = true
  end

  def track = @track ||= Track.new

  def painted_on_track(tag_name, field, **attributes)
    outer = Rapid::Tag.new
    Rapid::Context.capture { outer.with_field(field, track) { outer.call_tag(tag_name, attributes) } }
  end

  # The record you are creating goes under the association name; the one you are
  # choosing goes under the foreign key. They are two different questions and
  # they must not collide.
  def test_it_names_the_new_record_after_the_association
    html = painted_on_track(:select_one_or_new, :style)

    assert_includes html, %(name="track[style_id]")
    assert_includes html, %(name="track[style][name]")
  end

  def test_it_offers_the_extra_option_that_reveals_the_fields
    html = painted_on_track(:select_one_or_new, :style)

    assert_includes html, %(<option value="__new__")
    assert_includes html, %(data-controller="rapid-select-one-or-new")
    assert_includes html, %(data-rapid-select-one-or-new-target="select")
    assert_includes html, %(data-rapid-select-one-or-new-target="fields")
  end

  # `:accessible => true` is the model saying this one may be *created* from
  # here, not only chosen. Nobody edits a view to get it, and nobody gets it by
  # accident either.
  def test_input_offers_it_only_when_the_model_allows_creating
    assert_includes painted_on_track(:input, :style), "select-one-or-new"
    refute_includes painted_on_track(:input, :plain_style), "select-one-or-new"
  end

  # Inside a row of an <input-many> the names nest one level further, and both
  # halves have to nest together or the row builds a record nobody asked for.
  def test_inside_a_row_both_names_nest
    html = painted_on_track(:select_one_or_new, :style, :name => "album[tracks][2][style_id]")

    assert_includes html, %(name="album[tracks][2][style_id]")
    assert_includes html, %(name="album[tracks][2][style][name]")
  end

end
