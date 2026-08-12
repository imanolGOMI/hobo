require "test_helper"
require "hobo_rapid/theme"

# What a theme is: a table of class names and a list of stylesheets. And which
# one is in force, which is a question about **the part of the application that
# is painting** -- Hobo 2 asked for the admin subsite's theme separately, and it
# was a fair question.
class ThemeTest < Minitest::Test

  def setup
    HoboRapid::Theme.undress
    Thread.current[:hobo_rapid_subsite] = nil
  end

  def teardown
    HoboRapid::Theme.undress
    Thread.current[:hobo_rapid_subsite] = nil
  end

  def painting(subsite)
    Thread.current[:hobo_rapid_subsite] = subsite
    yield
  ensure
    Thread.current[:hobo_rapid_subsite] = nil
  end

  # --- one theme ---------------------------------------------------------------

  def test_a_theme_says_what_it_wears_and_what_things_are_called
    HoboRapid::Theme.wears("clean", "collection-table" => "striped")

    assert_equal ["clean"], HoboRapid::Theme.stylesheets
    assert_equal "collection-table striped", Rapid.dress("collection-table")
  end

  # A theme with no table at all is a perfectly good theme: its stylesheet
  # styles the roles the catalogue writes. That is what `clean` is.
  def test_a_theme_with_no_table_leaves_the_markup_alone
    HoboRapid::Theme.wears("clean")

    assert_equal "collection-table", Rapid.dress("collection-table")
  end

  # And no theme at all leaves it alone too -- which is what `--theme=none`
  # gives you: semantic names, and your own stylesheet.
  def test_with_no_theme_the_roles_are_what_comes_out
    assert_equal "index-page stories", Rapid.dress("index-page stories")
    assert_empty HoboRapid::Theme.stylesheets
  end

  # --- a subsite ---------------------------------------------------------------

  def test_a_subsite_without_a_theme_of_its_own_wears_the_sites
    HoboRapid::Theme.wears("clean")

    painting("admin") do
      assert_equal ["clean"], HoboRapid::Theme.stylesheets
    end
  end

  def test_a_subsite_can_wear_another_one
    HoboRapid::Theme.wears("clean")
    HoboRapid::Theme.wears("bootstrap", "hobo", :subsite => "admin", "action" => "btn")

    assert_equal ["clean"], HoboRapid::Theme.stylesheets
    assert_equal "action", Rapid.dress("action")

    painting("admin") do
      assert_equal %w[bootstrap hobo], HoboRapid::Theme.stylesheets
      assert_equal "action btn", Rapid.dress("action")
    end
  end

  # The asset pipeline precompiles once and the choice is made per request, so
  # it has to know about every stylesheet any part of the application might ask
  # for. A subsite whose theme was not precompiled is a subsite with no styles.
  def test_the_pipeline_hears_about_every_stylesheet
    HoboRapid::Theme.wears("clean")
    HoboRapid::Theme.wears("bootstrap", "hobo", :subsite => "admin")

    assert_equal %w[clean bootstrap hobo], HoboRapid::Theme.all_stylesheets
  end

  # --- los temas son gemas ---------------------------------------------------
  #
  # Hobo no conoce ningun tema por su nombre: cada uno se apunta al cargarse, y
  # `config.hobo.theme` elige entre los apuntados. Antes esto era un `case` con
  # `:bootstrap` dentro, y por eso Bootstrap vivia en la gema -- 232 KB de un
  # framework de terceros que se llevaba tambien quien no lo usaba.

  def test_a_theme_registers_itself
    Hobo.theme(:prueba) { |subsite| HoboRapid::Theme.wears("prueba", :subsite => subsite) }

    assert_includes Hobo.themes.keys, :prueba
  ensure
    Hobo.themes.delete(:prueba)
  end

  # Y el que viene dentro esta apuntado igual que los demas.
  def test_clean_is_registered_like_any_other
    require "hobo_clean"

    assert_includes Hobo.themes.keys, :clean
  end

  # Pedir un tema que no esta puesto se dice con todas las letras: lo que falta
  # es una gema en el Gemfile, y el mensaje lo tiene que decir.
  def test_asking_for_a_theme_that_is_not_installed
    error = assert_raises(ArgumentError) { Hobo::Engine.dress(:no_existe) }

    assert_includes error.message, "no esta"
    assert_includes error.message, %(gem "hobo_no_existe")
  end

end
