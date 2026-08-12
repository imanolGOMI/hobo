require "test_helper"

# `:accessible => true`: the option that lets a form build the records on the
# other side of an association, and the reason a genre can be created from
# inside the film without leaving the page.
#
# It is what `<input-many>` sends its rows to. The rows arrive the way a browser
# sends them -- `{"0" => {...}, "1" => {...}}`, from names like
# `movie[movie_genres][0][genre_id]` -- and this is what turns that into
# records. Not `accepts_nested_attributes_for`: no `_attributes` suffix, and a
# row may name a record that does not exist yet.
class AccessibleAssociationsTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:films, :force => true) { |t| t.string :title }
    ActiveRecord::Base.connection.create_table(:genres, :force => true) { |t| t.string :name }
    ActiveRecord::Base.connection.create_table(:film_genres, :force => true) do |t|
      t.integer :film_id
      t.integer :genre_id
    end

    Object.const_set(:Genre, Class.new(ActiveRecord::Base))
    Genre.class_eval do
      include Hobo::Model
      fields { name :string }
      def view_permitted?(field) = true
    end

    # Film first and without its association: `belongs_to :film` asks for the
    # class as it is declared, and Hobo asks it for more than Rails does.
    Object.const_set(:Film, Class.new(ActiveRecord::Base))
    Film.class_eval do
      include Hobo::Model
      fields { title :string }
      def view_permitted?(field) = true
    end

    Object.const_set(:FilmGenre, Class.new(ActiveRecord::Base))
    FilmGenre.class_eval do
      include Hobo::Model
      fields { }
      belongs_to :film, :optional => true
      belongs_to :genre, :optional => true
      def view_permitted?(field) = true
    end

    Film.class_eval do
      has_many :film_genres, :dependent => :destroy, :accessible => true
    end

    @noir = Genre.create!(:name => "Cine negro")
    @scifi = Genre.create!(:name => "Ciencia ficcion")
  end

  def teardown
    HoboTest.clean_up(:Film, :FilmGenre, :Genre)
  end

  # The one that would have caught it. An `end` in the wrong place closed the
  # module eighty lines early, so the macros were defined somewhere else and
  # never installed: `:accessible => true` was accepted, recorded in the
  # reflection, and did **nothing**. The hash of rows went straight to
  # ActiveRecord's writer, which wants records, and every nested form died with
  # "undefined method '&' for a Hash".
  def test_the_option_actually_installs_a_writer
    refute_equal "Film::GeneratedAssociationMethods",
                 Film.instance_method(:film_genres=).owner.to_s,
                 ":accessible => true no instalo nada: la escritura sigue siendo la de ActiveRecord"
  end

  def test_a_hash_of_rows_becomes_records
    film = Film.create!(:title => "Blade Runner")
    film.film_genres = { "0" => { "genre_id" => @scifi.id.to_s }, "1" => { "genre_id" => @noir.id.to_s } }
    film.save!

    assert_equal ["Ciencia ficcion", "Cine negro"], film.film_genres.reload.map { |fg| fg.genre.name }
  end

  # The keys are read as numbers, not as strings: "10" goes after "9", not
  # between "1" and "2".
  def test_the_rows_keep_the_order_of_their_indices
    film = Film.create!(:title => "Blade Runner")
    rows = (0..10).to_h { |i| [i.to_s, { "genre_id" => (i.even? ? @scifi : @noir).id.to_s }] }
    film.film_genres = rows
    film.save!

    assert_equal 11, film.film_genres.reload.length
    assert_equal @scifi.id, film.film_genres.first.genre_id
    assert_equal @scifi.id, film.film_genres.last.genre_id
  end

  # An existing row names itself, so the server can tell "change this one" from
  # "make another".
  def test_a_row_with_an_id_updates_instead_of_adding
    film = Film.create!(:title => "Blade Runner")
    film.film_genres = { "0" => { "genre_id" => @scifi.id.to_s } }
    film.save!
    existing = film.film_genres.reload.first

    film.film_genres = { "0" => { "id" => existing.id.to_s, "genre_id" => @noir.id.to_s } }
    film.save!

    assert_equal 1, film.film_genres.reload.length
    assert_equal existing.id, film.film_genres.first.id
    assert_equal @noir.id, film.film_genres.first.genre_id
  end

  # Removing every row has to be sayable. The browser cannot send an empty list,
  # so `<input-many>` sends an empty string, and it means "empty".
  def test_an_empty_string_empties_the_collection
    film = Film.create!(:title => "Blade Runner")
    film.film_genres = { "0" => { "genre_id" => @scifi.id.to_s } }
    film.save!

    film.film_genres = ""
    film.save!

    assert_equal 0, film.film_genres.reload.length
  end

end
