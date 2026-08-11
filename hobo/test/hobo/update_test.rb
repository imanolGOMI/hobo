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

  # --- paperclip ----------------------------------------------------------------

  # The declaration is translated; the files are not, and that is said rather
  # than attempted -- they are on a disk or in a bucket and only the application
  # knows which.
  def test_has_attached_file_becomes_has_one_attached
    modelo = <<~RUBY
      class Company < ActiveRecord::Base
        has_attached_file :logo,
            :styles => { :medium => ["400x400", :jpg] },
            :path => 'lib/logos/:style/:filename'
        validates_attachment_content_type :logo, :content_type => /image/
        def name = "x"
      end
    RUBY

    escrito = rewrite_model("company.rb", modelo)

    assert_includes escrito, "has_one_attached :logo"
    refute_includes escrito, "has_attached_file"
    refute_includes escrito, "validates_attachment"
    assert_includes escrito, 'def name = "x"', "lo demas del modelo se queda"
  end

  def test_the_columns_paperclip_left_are_named
    write("app/models/company.rb", "class Company\n  has_attached_file :logo\nend")

    assert_includes updater.paperclip_columns, "logo_file_name"
    assert_includes updater.paperclip_columns, "logo_updated_at"
  end

  # --- the classes -------------------------------------------------------------

  # Hobo 3 emits a **role** and the theme dresses it, so a template that says
  # the role is dressed by whichever theme is installed.
  def test_a_theme_class_becomes_the_role
    assert_equal %(<a class="action new">x</a>),
                 rewrite_classes(%(<a class="btn btn-primary">x</a>))
  end

  def test_the_classes_around_it_are_left_alone
    assert_equal %(<div class="icono-box action">x</div>),
                 rewrite_classes(%(<div class="icono-box btn">x</div>))
  end

  # `span4` maps to `col-md-4`, which is Bootstrap 2 to Bootstrap 5: somebody
  # else's map, thousands of classes, and not ours to keep up to date
  # (decision 23). It is listed, not changed.
  def test_a_bootstrap_class_is_not_touched
    assert_equal %(<div class="span4">x</div>), rewrite_classes(%(<div class="span4">x</div>))
  end

  def test_the_bootstrap_classes_the_application_uses_are_listed
    write("app/views/x/y.dryml", %(<div class="span4 pull-right">x</div>))

    assert_equal %w[span4 pull-right].sort, updater.bootstrap_classes.sort
  end

  # `bootstrap-sass` came in with `hobo_bootstrap` in an application on that
  # theme, and the theme brings its own Bootstrap now. In one on `clean` the
  # application added it itself, and dropping it takes away a design nobody
  # asked us to touch.
  def test_bootstrap_sass_is_dropped_only_when_it_was_hobos
    write("Gemfile", %(gem "hobo_bootstrap"\ngem "bootstrap-sass"\n))

    assert_includes updater.retired_gems, "bootstrap-sass"
  end

  def test_bootstrap_sass_stays_when_the_application_added_it
    write("Gemfile", %(gem "hobo"\ngem "bootstrap-sass"\n))

    refute_includes updater.retired_gems, "bootstrap-sass"
    assert_includes updater.kept_gems, "bootstrap-sass"
  end

  # And it is said that it will not build: Propshaft serves files, it does not
  # process them.
  def test_the_sass_gems_are_named
    write("Gemfile", %(gem "hobo"\ngem "bootstrap-sass"\n))

    assert_equal ["bootstrap-sass"], updater.sass_gems
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

  # The pass writes files, so the fixture is a file and what comes back is what
  # is on disk.
  def rewrite_classes(markup)
    target = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(File.join(target, "app", "views", "x"))
    file = File.join(target, "app", "views", "x", "y.dryml")
    File.write(file, markup)
    updater.send(:write_theme_classes)
    File.read(file)
  ensure
    FileUtils.rm_rf(target)
  end

  def rewrite_model(name, content)
    target = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(File.join(target, "app", "models"))
    file = File.join(target, "app", "models", name)
    File.write(file, content)
    updater.send(:write_attachments)
    File.read(file)
  ensure
    FileUtils.rm_rf(target)
  end

  def write(path, content)
    full = File.join(@directory, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

end
