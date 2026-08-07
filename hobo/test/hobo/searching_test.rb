require "test_helper"
require "ransack"

# Piece 6's replacement, which piece 11 is the customer of.
#
# The 429 lines of automatic scopes had two live callers: the `<attr>_contains`
# of the autocompleter and the `order_by` of <table-plus>'s sorting. Ransack
# answers the first; the relation's own `order` answers the second.
class SearchingTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:articles, :force => true) do |t|
      t.string :title
      t.string :author
      t.string :secret
    end

    Object.const_set(:Article, Class.new(ActiveRecord::Base))
    Article.class_eval do
      include Hobo::Model
      fields do
        title  :string
        author :string
        secret :string
      end
      never_show :secret
    end

    Article.create!(:title => "Rails and Hobo", :author => "Tom",    :secret => "x")
    Article.create!(:title => "Ruby",          :author => "Imanol",  :secret => "y")
    Article.create!(:title => "Hobo forever",  :author => "Someone", :secret => "z")
  end

  def teardown
    HoboTest.clean_up(:Article)
  end

  # --- what a Hobo model lets anyone search ------------------------------------
  #
  # Ransack 4 refuses to search a model that has not said which attributes may
  # be searched. Hobo already knows, so it answers for itself.

  def test_a_model_offers_its_own_columns
    assert_includes Article.ransackable_attributes, "title"
    assert_includes Article.ransackable_attributes, "author"
  end

  def test_a_field_the_model_never_shows_is_not_searchable
    refute_includes Article.ransackable_attributes, "secret"
  end

  def test_associations_are_not_searchable_unless_a_model_says_so
    assert_equal [], Article.ransackable_associations
  end

  # --- the autocompleter's query ----------------------------------------------

  def test_contains_finds_the_matching_records
    found = Article.ransack("title_cont" => "Hobo").result

    assert_equal ["Hobo forever", "Rails and Hobo"], found.map(&:title).sort
  end

  # Several attributes at once: what used to be a list of `_contains` scopes.
  def test_several_attributes_at_once
    found = Article.ransack("title_or_author_cont" => "Imanol").result

    assert_equal ["Ruby"], found.map(&:title)
  end

  def test_searching_a_field_the_model_never_shows_finds_nothing
    found = Article.ransack("secret_cont" => "x").result

    assert_equal 3, found.count, "el predicado sobre un campo no buscable se ignora"
  end

  # --- the sorting ------------------------------------------------------------

  def test_ordering_by_a_marked_string_works
    ordered = Article.order(Arel.sql("title asc"))

    assert_equal ["Hobo forever", "Rails and Hobo", "Ruby"], ordered.map(&:title)
  end

  # Rails 6 and 7 refused a raw expression in `order` unless it was marked safe;
  # Rails 8 allows it again. Marking it says the string is deliberate instead of
  # depending on which way Rails currently leans -- and parse_sort_param is the
  # right place to say so, because it is the one place holding the whitelist.
  def test_the_same_expression_marked_as_safe_goes_through
    ordered = Article.order(Arel.sql("LENGTH(title) asc"))

    assert_equal "Ruby", ordered.first.title
  end

end
