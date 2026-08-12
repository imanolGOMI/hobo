require "test_helper"
require_relative "../prepare_testapp"

# That an application gets Hobo's words, and gets them in its own language.
#
# The unit test of the translation layer loads `config/locales/hobo.es.yml` by
# path, so it passes whether or not the gem ever hands that file to anybody.
# What an application needs is for the **engine** to ship it, and that is an
# absence no test written from the runtime can see -- the same shape of hole as
# the theme that was built and never connected.
#
#   cd hobo && rake test:app
class I18nIntegrationTest < Minitest::Test

  def setup
    skip TestApp.why_not unless TestApp.built?
    TestApp.sweep
  end

  def test_the_engine_ships_its_locales
    assert_equal "true", runner(%(print I18n.load_path.grep(/hobo\\.es\\.yml/).any?))
  end

  # English is not in a file: it is written at the point of use, as the default
  # of each key. Both halves have to arrive.
  def test_an_application_speaks_english_and_can_speak_spanish
    assert_equal "Create", runner(<<~RUBY)
      I18n.locale = :en
      print HoboRapid.translate(:"actions.create", "Create")
    RUBY

    assert_equal "Crear", runner(<<~RUBY)
      I18n.locale = :es
      print HoboRapid.translate(:"actions.create", "Create")
    RUBY
  end

  # And the words reach the markup, which is the only place they matter.
  def test_a_derived_page_is_painted_in_the_language_of_the_application
    assert_equal "Nuevo relato", runner(<<~RUBY)
      I18n.locale = :es
      print HoboRapid.translate(:"index.new_link", "New %{name}", :name => "relato")
    RUBY
  end

  # Choosing a language used to be enough to break the application: Rails ships
  # date formats for English only, and `l(date)` in any other language raises
  # "translation missing: es.date.formats.default" -- so **every list with a
  # date on it answered 500**. Found in an application built with the old Hobo,
  # which asked the same question and warned about this in yellow text nobody
  # reads.
  def test_a_date_can_be_shown_in_spanish
    assert_equal "10/08/2026", runner(<<~RUBY)
      I18n.locale = :es
      print I18n.l(Date.new(2026, 8, 10))
    RUBY
  end

  def test_the_months_have_spanish_names
    assert_equal "agosto", runner(<<~RUBY)
      I18n.locale = :es
      print I18n.t("date.month_names")[8]
    RUBY
  end

  private

  def runner(script)
    file = File.join(TestApp::PATH, "tmp", "probe.rb")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, script)
    TestApp.run("bin/rails runner #{file}").strip
  ensure
    FileUtils.rm_f(file)
  end

end
