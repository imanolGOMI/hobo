require "test_helper"
require "cgi"
require "rapid/param_contract"
require "hobo_rapid/tags/filters"

# Piece 6, as it ended up: the scopes went to Ransack and this is the markup
# that talks to it.
#
# They are **not** derived, and that is decision 18: the index Hobo 2 derived
# had no filters either -- you wrote `<search-filter>` in your own page when you
# wanted it. What Hobo gives you is that it works with nothing else written.
class FiltersTest < Minitest::Test
  include ParamContract::Assertions

  Category = Struct.new(:id, :name) do
    def viewable_by?(_user) = true
  end

  class CategoryScope
    CATEGORIES = [Category.new(1, "Drama"), Category.new(2, "Comedia")].freeze
    def self.limit(_n) = self
    def self.select(&block) = CATEGORIES.select(&block)
  end

  Reflection = Struct.new(:klass, :foreign_key, :macro, :options, :name)

  class Movie
    def self.field_specs = { :title => nil, :synopsis => nil }
    def self.name_attribute = :title
    def self.reflections
      { "category" => Reflection.new(CategoryScope, "category_id", :belongs_to, {}, :category) }
    end
    def self.name = "Movie"
  end

  # A collection knows what it holds; a Relation answers `klass`.
  class Movies
    def self.klass = Movie
    def self.each(&block) = [].each(&block)
  end

  def painted(tag_name, attributes = {}, query = {})
    HoboRapid.with_request(nil, nil, {}, query) do
      Rapid.render(tag_name, attributes, :this => Movies)
    end
  end

  # --- <search-filter> ---------------------------------------------------------

  # `q[title_cont]` is Ransack's own spelling, and `title` is what the model
  # calls its name -- which is what a person means when they type into a list of
  # things.
  def test_it_searches_the_name_of_the_thing_by_default
    assert_includes painted(:search_filter), %(name="q[title_cont]")
  end

  def test_several_fields_are_one_condition
    assert_includes painted(:search_filter, :fields => "title, synopsis"),
                    %(name="q[title_or_synopsis_cont]")
  end

  def test_the_box_remembers_what_was_searched
    html = painted(:search_filter, {}, :q => { "title_cont" => "blade" })

    assert_includes html, %(value="blade")
  end

  # A button that does nothing is a button you learn to ignore.
  def test_there_is_nothing_to_clear_until_there_is
    refute_includes painted(:search_filter), "Clear"
    assert_includes painted(:search_filter, {}, :q => { "title_cont" => "blade" }), "Clear"
  end

  # --- <filter-menu> -----------------------------------------------------------

  def test_a_belongs_to_becomes_a_menu_of_its_records
    html = painted(:filter_menu, :field => "category")

    assert_includes html, %(name="q[category_id_eq]")
    assert_includes html, ">Drama<"
    assert_includes html, ">Comedia<"
  end

  # The `>` comes out as `&gt;`, which is what an attribute value is supposed to
  # look like -- the browser reads it back as `>`, and the browser test of the
  # user changer, which is wired the same way, proves it end to end.
  def test_it_submits_itself
    html = painted(:filter_menu, :field => "category")

    # En el formulario, no en el select: quien lo ejecute solo alcanza su
    # elemento, y el boton de reserva que esconde es hermano del select.
    assert_includes html, %(class="filter-menu" data-rapid=)
    assert_includes CGI.unescapeHTML(html), %({"autosubmit":{}})
    assert_includes html, %(data-rapid-action="autosubmit:submit")
    assert_includes html, %(data-rapid-target="autosubmit:fallback")
  end

  def test_the_menu_remembers_what_was_chosen
    html = painted(:filter_menu, { :field => "category" }, :q => { "category_id_eq" => "2" })

    assert_includes html, %(<option value="2" selected>)
  end

  def test_a_plain_list_of_options_works_too
    html = painted(:filter_menu, :param => "year_eq", :options => [1960, 1982])

    assert_includes html, %(name="q[year_eq]")
    assert_includes html, ">1982<"
  end

  # --- the one that matters ----------------------------------------------------
  #
  # Two filters on one page have to add up, not take turns. Each form carries
  # what the other one has, or picking a category throws away the search you had
  # typed -- and it does it silently, which is the worst way to lose something.

  def test_a_filter_keeps_what_the_others_have
    query = { :q => { "title_cont" => "blade", "category_id_eq" => "2" } }

    menu = painted(:filter_menu, { :field => "category" }, query)
    assert_includes menu, %(<input type="hidden" name="q[title_cont]" value="blade">)

    search = painted(:search_filter, {}, query)
    assert_includes search, %(<input type="hidden" name="q[category_id_eq]" value="2">)
  end

  # ...and clearing the search clears the search, not the page.
  def test_clearing_keeps_the_other_filters
    html = painted(:search_filter, {}, :q => { "title_cont" => "blade", "category_id_eq" => "2" })

    assert_includes html, "q[category_id_eq]=2"
    refute_includes html, "q[title_cont]=blade&"
  end

  # --- the contract ------------------------------------------------------------

  def test_every_param_of_the_search_filter_is_overridable
    assert_every_param_overridable(:search_filter, [
      { :name => "sin busqueda", :this => Movies },
      { :name => "buscando", :this => Movies,
        :attributes => { :label => "Buscar" } }
    ])
  end

  def test_every_param_of_the_filter_menu_is_overridable
    assert_every_param_overridable(:filter_menu,
                                   { :name => "un menu", :this => Movies,
                                     :attributes => { :field => "category", :label => "Categoria" } })
  end

end
