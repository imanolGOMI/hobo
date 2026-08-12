require "test_helper"
require "i18n"
require "hobo_rapid/translation"
require "hobo_rapid/tags/filters"
require "hobo_rapid/tags/structure"

# The words of the catalogue, and how another language gets them.
#
# The English is written at the point of use, as the `:default` of the key, so
# there is no `hobo.en.yml` repeating it -- two lists of the same strings drift
# apart and the one nobody reads is the one that is wrong. What ships is
# `config/locales/hobo.es.yml`, and this is the check that it reaches the page.
class TranslationTest < Minitest::Test

  SPANISH = File.expand_path("../../config/locales/hobo.es.yml", __dir__)

  def setup
    @load_path = I18n.load_path.dup
    @locale = I18n.locale
    I18n.load_path |= [SPANISH]
    I18n.backend.reload!
  end

  def teardown
    I18n.load_path = @load_path
    I18n.locale = @locale
    I18n.backend.reload!
  end

  # --- the default is the translation -----------------------------------------

  def test_a_key_nobody_translated_says_the_english_written_at_the_point_of_use
    I18n.locale = :en

    assert_equal "Create", HoboRapid.translate(:"actions.create", "Create")
    assert_equal "Save", HoboRapid.translate(:"actions.save", "Save")
  end

  def test_a_language_that_has_the_key_wins
    I18n.locale = :es

    assert_equal "Crear", HoboRapid.translate(:"actions.create", "Create")
  end

  # An application overrides a gem's translations the ordinary Rails way, by
  # having the same key: nothing about this is special to Hobo.
  def test_an_application_can_have_its_own_english
    I18n.backend.store_translations(:en, :hobo => { :actions => { :create => "Add" } })
    I18n.locale = :en

    assert_equal "Add", HoboRapid.translate(:"actions.create", "Create")
  end

  # --- interpolation ------------------------------------------------------------

  # This is the reason the strings are keys and not concatenations: "New story"
  # and "Nuevo relato" do not put the noun in the same place, and no amount of
  # `"New " + noun` gets there.
  def test_the_noun_travels_as_a_value_and_lands_where_the_language_puts_it
    I18n.locale = :es

    assert_equal "Nuevo relato", HoboRapid.translate(:"index.new_link", "New %{name}", :name => "relato")
  end

  def test_the_default_interpolates_too
    I18n.locale = :en

    assert_equal "New story", HoboRapid.translate(:"index.new_link", "New %{name}", :name => "story")
    assert_equal "3 errors stopped this Story from being saved",
                 HoboRapid.translate(:"errors.many", "%{count} errors stopped this %{name} from being saved",
                                     :count => 3, :name => "Story")
  end

  # --- on a page ------------------------------------------------------------------

  # The tags themselves, not the helper: a string that never reaches a tag is a
  # string nobody sees translated.
  def test_a_tag_paints_the_language_of_the_request
    I18n.locale = :es

    assert_includes filter, "Buscar"
    refute_includes filter, "Search"
  end

  def test_and_the_same_tag_speaks_english_by_default
    I18n.locale = :en

    assert_includes filter, "Search"
  end

  # The catalogue has to be renderable with the runtime and nothing else -- the
  # piece tests do exactly that -- so the words cannot depend on I18n being
  # loaded.
  def test_without_i18n_the_default_is_the_answer
    assert_equal "New story", HoboRapid.interpolate("New %{name}", :name => "story")
    assert_equal "Create", HoboRapid.interpolate("Create", {})
  end

  private

  # A collection, as an index page has: what <search-filter> asks the model for
  # is the field it searches by default.
  class Story
    def self.field_specs = { :title => nil }
    def self.name_attribute = :title
    def self.name = "Story"
  end

  class Stories
    def self.klass = Story
    def self.each(&block) = [].each(&block)
  end

  def filter
    HoboRapid.with_request(nil, nil, {}, {}) do
      Rapid.render(:search_filter, {}, :this => Stories)
    end
  end

end
