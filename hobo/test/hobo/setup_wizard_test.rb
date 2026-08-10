require "test_helper"
require "rails/generators"
require "generators/hobo/setup_wizard/setup_wizard_generator"

# The questions, and what an answer that never gets asked comes out as.
#
# The wizard is the only place that asks, so what it decides when nobody is
# there to answer -- a script, `hobo new` with flags, a test -- is as much part
# of it as the questions themselves. These run it with `--no-wizard`, which is
# exactly that case, and read what it decided.
#
# Written after four of the questions Hobo 2 asked turned out to be missing:
# the initial migration, the languages, the git commit, and a search box that
# had become a question when it never was one.
class SetupWizardTest < Minitest::Test

  def wizard(options = {})
    generator = Hobo::Generators::SetupWizardGenerator.new([], options.merge(:wizard => false))
    generator.ask_the_questions
    generator
  end

  def answer(generator, name) = generator.instance_variable_get(:"@#{name}")

  # Hobo 2 gave every application `/search` and the box in the bar without
  # asking, and a question with a default of "no" was taking it away from
  # everybody who did not read it.
  def test_the_search_box_comes_without_being_asked_for
    assert_equal true, answer(wizard, :search)
  end

  def test_no_search_takes_the_box_away
    assert_equal false, answer(wizard(:search => false), :search)
  end

  # --- the languages ---------------------------------------------------------

  def test_english_alone_by_default
    generator = wizard
    assert_equal %w[en], answer(generator, :locales)
    assert_equal "en", answer(generator, :locale)
  end

  def test_a_list_of_languages_and_the_first_is_the_default
    generator = wizard(:locales => %w[en es])
    assert_equal %w[en es], answer(generator, :locales)
    assert_equal "en", answer(generator, :locale)
  end

  # `--locales=en,es` and `--locales en es` are the same answer typed two ways.
  def test_the_list_can_come_with_commas
    assert_equal %w[en es], answer(wizard(:locales => ["en,es"]), :locales)
  end

  def test_the_default_language_can_be_the_second
    generator = wizard(:locales => %w[en es], :locale => "es")
    assert_equal %w[en es], answer(generator, :locales)
    assert_equal "es", answer(generator, :locale)
  end

  # `--locale=es` on its own still means Spanish and only Spanish, which is what
  # it meant before there was a list.
  def test_one_language_on_its_own
    generator = wizard(:locale => "es")
    assert_equal %w[es], answer(generator, :locales)
    assert_equal "es", answer(generator, :locale)
  end

  # A language nobody has asked for cannot be the default: it would raise on the
  # first request.
  def test_a_default_outside_the_list_is_ignored
    assert_equal "en", answer(wizard(:locales => %w[en], :locale => "fr"), :locale)
  end

  def test_hobo_knows_which_languages_it_speaks
    assert_includes HoboRapid::TRANSLATED_LOCALES, "en"
    assert_includes HoboRapid::TRANSLATED_LOCALES, "es"
  end

  # --- the initial migration -------------------------------------------------
  #
  # Asked with the rest and in Hobo 2's own order -- after the front page,
  # before the languages -- and **done** at the end, which is the shape that
  # took three tries: the answer belongs with the questions and the work with
  # the work.

  # With nobody to ask, the migration runs: an application whose columns are not
  # there fails on its first page, and that was the state `hobo new` used to
  # leave behind.
  def test_the_migration_runs_when_nobody_answers
    assert_equal :migrate, answer(wizard, :migration)
    assert_equal "-n -m", wizard.send(:migration_flags)
  end

  def test_skip_migration
    assert_equal :skip, answer(wizard(:skip_migration => true), :migration)
  end

  def test_generate_migration_writes_it_without_running_it
    generator = wizard(:generate_migration => true)
    assert_equal :generate, answer(generator, :migration)
    assert_equal "-n -g", generator.send(:migration_flags)
  end

  # The wizard answers it, so the generator it calls does not ask it again: it
  # prints the migration -- which is what there was to see -- and does what it
  # was told.
  def test_the_generator_is_never_asked_to_ask
    assert_includes wizard.send(:migration_flags), "-n"
  end

  # --- git -------------------------------------------------------------------

  # No commit unless somebody says so: a generator that commits on its own has
  # an opinion about somebody else's history.
  def test_no_commit_unless_asked
    assert_equal false, answer(wizard, :git)
  end

  def test_git_commits_the_work
    assert_equal true, answer(wizard(:git => true), :git)
  end

end
