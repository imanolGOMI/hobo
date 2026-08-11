require "test_helper"
require "hobo/update"
require "tmpdir"

# `hobo update`: bringing an application written for Hobo 2 to this one.
#
# What is tested here is the reading and the rewriting, not the copying: an
# application is built by `hobo new`, which has its own tests, and the part that
# can be wrong in a quiet way is what this does to somebody's routes and models.
#
# Every case below is one that actually happened while upgrading amenti, and
# each one of them made the whole application answer 404 or refuse to boot.
class UpdateTest < Minitest::Test

  def setup
    @directory = Dir.mktmpdir("hobo_update")
    FileUtils.mkdir_p(File.join(@directory, "config"))
    File.write(File.join(@directory, "config", "application.rb"), "")
  end

  def teardown = FileUtils.remove_entry(@directory)

  def updater = Hobo::Update.new(@directory, :out => StringIO.new)

  # --- the routes -------------------------------------------------------------

  # The extra blank line stands in for the rest of a real routes file: without
  # it the last line is the one before `end` and comes back with no newline,
  # which is an artefact of the fixture and not of the rewriting.
  def body(routes) = updater.old_routes_body("Amenti::Application.routes.draw do\n#{routes}\n\nend\n")

  def test_match_gets_a_verb
    assert_equal "  match 'ayuda' => 'front#ayuda', :via => :all\n",
                 body("  match 'ayuda' => 'front#ayuda'")
  end

  def test_a_match_that_already_says_via_is_left_alone
    line = "  match 'x' => 'y#z', :via => :post\n"
    assert_equal line, body(line.chomp)
  end

  # `if` is a modifier and has to stay last. Appending after it made a line that
  # does not parse, and a routes file that does not parse is an application with
  # no routes at all.
  def test_via_goes_before_a_trailing_if
    assert_equal "  match ENV['ROOT'] => 'front#index', :via => :all if ENV['ROOT']\n",
                 body("  match ENV['ROOT'] => 'front#index' if ENV['ROOT']")
  end

  # Route files of that age wrap. Rewriting line by line put `, :via => :all`
  # after the trailing comma and left `,,` in the file.
  def test_a_match_split_over_several_lines
    written = body(<<~ROUTES.chomp)
        match 'presupuestos', :controller => :expedientes,
              :action => :presupuestos
    ROUTES

    assert_includes written, ":action => :presupuestos, :via => :all"
    refute_includes written, ",,"
  end

  def test_what_is_not_a_match_is_untouched
    line = "  resources :clientes\n"
    assert_equal line, body(line.chomp)
  end

  # A route name may only be used once, and both files name some of the same
  # things. Rails refuses to load the file at all when the two meet.
  def test_the_names_the_old_file_uses_are_found_either_way_round
    names = updater.route_names(<<~ROUTES)
      match 'search' => 'front#search', :as => 'site_search'
      get "/otra" => "x#y", as: :otra_cosa
    ROUTES

    assert_includes names, "site_search"
    assert_includes names, "otra_cosa"
  end

  # --- what is read from the application --------------------------------------

  def test_it_counts_the_dryml_and_tells_the_generated_ones_apart
    write("app/views/clientes/index.dryml", "<index-page:/>")
    write("app/views/taglibs/auto/rapid/pages.dryml", "<!-- generado -->")

    assert_equal 2, updater.dryml_templates.length
  end

  def test_it_finds_attr_accessible_and_paperclip
    write("app/models/pago.rb", "class Pago\n  attr_accessible :importe\nend")
    write("app/models/company.rb", "class Company\n  has_attached_file :logo\nend")

    assert_equal ["pago"], updater.attr_accessible_models
    assert_equal ["company"], updater.paperclip_models
  end

  def test_the_gems_are_split_into_kept_and_retired
    write("Gemfile", <<~GEMFILE)
      gem "rails", "3.2.22"
      gem "hobo"
      gem "turbolinks"
      gem "geocoder"
    GEMFILE

    assert_equal %w[rails turbolinks], updater.retired_gems
    assert_equal ["geocoder"], updater.kept_gems, "hobo es de Hobo 2 y no cruza"
  end

  # The report is what somebody reads before deciding to do this at all, so a
  # run that looks and changes nothing has to say something.
  def test_looking_changes_nothing_and_says_what_it_found
    write("app/views/clientes/index.dryml", "<index-page:/>")
    write("Gemfile", %(gem "turbolinks"\n))

    out = StringIO.new
    Hobo::Update.new(@directory, :out => out).run

    assert_match(/1 plantillas DRYML/, out.string)
    assert_match(/turbolinks/, out.string)
    assert_match(/Nada escrito/, out.string)
    refute File.exist?(File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3"))
  end

  private

  def write(path, content)
    full = File.join(@directory, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

end
