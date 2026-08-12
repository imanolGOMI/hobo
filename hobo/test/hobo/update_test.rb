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

  # El paso del tema no las toca: son de Bootstrap, no de Hobo, y las cambia el
  # paso de al lado.
  def test_a_bootstrap_class_is_not_the_theme_pass_business
    assert_equal %(<div class="span4">x</div>), rewrite_classes(%(<div class="span4">x</div>))
  end

  # --- Bootstrap 2 -> Bootstrap 5 -------------------------------------------------
  #
  # Se listaban y no se tocaban, y eso se cayo al mirar la pagina: `span5` y
  # `span7` son las dos columnas de la portada de amenti, y sin ellas todo queda
  # en una tira. `hidden` es peor -- en Bootstrap 5 no existe, asi que lo que
  # estaba escondido **aparece**.

  # `col-lg-5` y no `col-md-5`: son **dos** saltos. Bootstrap 3 lo llamo
  # `col-md-5` y Bootstrap 4 corrio la rejilla un punto, asi que el equivalente
  # de un `span5` de Bootstrap 2 en el 5 es `col-lg-5`. Encadenar no es lo mismo
  # que traducir de una vez, y esta prueba es la que lo dice.
  def test_the_grid_is_rewritten
    assert_equal %(<div class="col-lg-5">x</div>), rewrite_bootstrap(%(<div class="span5">x</div>))
  end

  def test_hidden_becomes_the_class_that_still_hides
    assert_equal %(<h1 class="d-none">Amenti</h1>), rewrite_bootstrap(%(<h1 class="hidden">Amenti</h1>))
  end

  # Bootstrap 5 lee sus atributos con `bs` delante, y sin eso su javascript no
  # se entera de que el componente existe: el carrusel se queda quieto con todas
  # las fotos una encima de otra.
  def test_the_data_attributes_get_their_bs
    assert_includes rewrite_bootstrap(%(<a data-slide="prev" data-target="#c">x</a>)), %(data-bs-slide="prev")
    assert_includes rewrite_bootstrap(%(<a data-slide="prev" data-target="#c">x</a>)), %(data-bs-target="#c")
  end

  # `item` es demasiado corriente para cambiarlo en cualquier sitio, y dentro de
  # un carrusel tiene que ser `carousel-item` o las fotos se apilan.
  def test_item_becomes_carousel_item_only_inside_a_carousel
    inside = %(<div class="carousel-inner"><div class="active item">x</div></div>)

    assert_includes rewrite_bootstrap(inside), %(class="active carousel-item")
    assert_equal %(<li class="item">x</li>), rewrite_bootstrap(%(<li class="item">x</li>))
  end

  # Bootstrap 2 le daba `max-width: 100%` a toda imagen y Bootstrap 3 quito esa
  # regla: sin clases, la foto sale a tamano natural y rompe la columna.
  def test_the_photo_gets_the_classes_that_keep_it_inside
    inside = %(<div class="carousel-inner"><div class="item"><img src="/a.png"/></div></div>)

    assert_includes rewrite_bootstrap(inside), %(<img src="/a.png" class="d-block w-100"/>)
  end

  def test_an_image_that_already_says_its_classes_is_left_alone
    inside = %(<div class="carousel-inner"><div class="item"><img src="/a.png" class="mia"/></div></div>)

    assert_includes rewrite_bootstrap(inside), %(class="mia")
    refute_includes rewrite_bootstrap(inside), "d-block"
  end

  def test_the_arrows_get_their_own_names
    inside = %(<div class="carousel-inner">x</div><a class="carousel-control left">&lsaquo;</a>)

    assert_includes rewrite_bootstrap(inside), %(class="carousel-control-prev")
  end

  # Bootstrap **si** tiene iconos: `bootstrap-icons`, oficial. Lo que no hace es
  # meterlos en el css del framework. Los nombres no coinciden -- `ok` es
  # `check`, `remove` es `x` -- asi que hay tabla.
  def test_the_icons_become_bootstrap_icons
    assert_equal %(<i class="bi bi-trash"></i>), rewrite_bootstrap(%(<i class="icon-trash"></i>))
    assert_equal %(<i class="bi bi-check-lg"></i>), rewrite_bootstrap(%(<i class="icon-ok icon-white"></i>))
  end

  # Y lo que la aplicacion define en su propio css **se queda al lado**: si
  # retoco `.well` a mi gusto, cambiarle el nombre a secas se lleva mi regla por
  # delante y la pagina sale distinta sin que nadie sepa por que.
  def test_a_class_the_application_styles_itself_is_kept_alongside
    write("app/assets/stylesheets/mio.css", ".well { background: pink }")

    assert_equal %(<div class="card card-body well">x</div>), rewrite_bootstrap(%(<div class="well">x</div>))
  end

  def test_a_class_the_application_does_not_style_is_simply_replaced
    assert_equal %(<div class="card card-body">x</div>), rewrite_bootstrap(%(<div class="well">x</div>))
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

  # --- the Gemfile it writes ---------------------------------------------------

  # The one gem this command can decide on its own: it has just counted the
  # templates. Without it every one of those pages comes out derived, and the
  # first run after an update looked worse than it was.
  def test_dryml_templates_bring_their_gem_in
    write("app/views/clientes/index.dryml", "<index-page:/>")

    assert_match(/^gem "hobo_dryml"$/, gemfile_after_update(%(gem "rails"\n)))
  end

  def test_an_application_with_no_dryml_does_not_get_the_gem
    refute_match(/hobo_dryml/, gemfile_after_update(%(gem "rails"\n)))
  end

  # Rails 8 writes its own capybara. Naming it twice is only a warning from
  # bundler -- on every command the application runs from then on.
  def test_a_gem_the_skeleton_already_asks_for_is_not_repeated
    write("Gemfile", %(gem "capybara"\ngem "geocoder"\n))

    written = gemfile_after_update(%(gem "rails"\ngem "capybara"\n))

    assert_equal 1, written.scan(/gem "capybara"/).length
    assert_match(/gem "geocoder"/, written)
  end

  # The report said bootstrap-sass was gone and the Gemfile installed it two
  # lines later: `kept_gems` subtracted the table, and the table does not have
  # it because it is only retired when it was Hobo's.
  def test_what_the_report_calls_retired_does_not_come_across
    write("Gemfile", %(gem "hobo_bootstrap"\ngem "bootstrap-sass"\n))

    refute_includes updater.kept_gems, "bootstrap-sass"
  end

  # --- lo que se llevaba por delante --------------------------------------------

  # `app` esta en la lista de lo que se copia, y se copiaba con un `rm_rf`
  # delante: el `app/` generado se iba entero, y con el la autenticacion de
  # Rails que `hobo new` acababa de escribir. `/session/new` contestaba 500 con
  # `uninitialized constant SessionsController` en una aplicacion que pintaba
  # todas las demas paginas.
  def test_the_skeleton_keeps_what_the_old_application_does_not_have
    write("app/models/user.rb", "class User; end")

    skeleton = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(File.join(skeleton, "app", "controllers"))
    File.write(File.join(skeleton, "app", "controllers", "sessions_controller.rb"), "generado")
    FileUtils.mkdir_p(File.join(skeleton, "app", "models"))
    File.write(File.join(skeleton, "app", "models", "user.rb"), "generado")

    updater.send(:carry)

    assert_equal "generado", File.read(File.join(skeleton, "app", "controllers", "sessions_controller.rb"))
    assert_equal "class User; end", File.read(File.join(skeleton, "app", "models", "user.rb")),
                 "lo que la aplicacion vieja si trae, manda"
  ensure
    FileUtils.rm_rf(File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3"))
  end

  # --- las hojas de estilo ------------------------------------------------------
  #
  # En Rails 3 una hoja era un manifiesto de Sprockets. Propshaft sirve ficheros
  # y no los procesa, asi que cada `*= require` es un comentario muerto y lo que
  # traia no lo enlaza nadie: el diseno entero de la aplicacion desaparecia.

  def test_a_sprockets_manifest_becomes_the_css_it_stood_for
    write("app/assets/stylesheets/application.css", "/*\n *= require_self\n */\nbody { color: red }")
    write("app/assets/stylesheets/front.scss", "/*\n *= require application\n *= require_tree ./front\n *= require hobo_rapid\n */")
    write("app/assets/stylesheets/front/saturno.css", ".saturno { color: blue }")

    written = resolve_stylesheets

    assert_includes written["application.css"], "body { color: red }", "lo que traia `require application`"
    assert_includes written["application.css"], ".saturno { color: blue }", "lo que traia `require_tree`"
    refute_includes written["application.css"], "require_tree", "las directivas son comentarios muertos"
  end

  # Un `require` que nombra una gema no se inventa: Hobo 3 trae su propio tema.
  def test_a_require_naming_a_gem_is_left_alone
    write("app/assets/stylesheets/front.css", "/*\n *= require hobo_rapid\n */\n.mia { color: red }")

    assert_includes resolve_stylesheets["application.css"], ".mia { color: red }"
  end

  # --- lo que no se puede convertir ---------------------------------------------

  # Hobo 2 guardaba `crypted_password` y `salt`; Rails 8 guarda `password_digest`,
  # que es bcrypt. Son algoritmos distintos: la aplicacion arranca, las paginas
  # se ven y **nadie puede entrar**.
  def test_the_old_password_columns_are_named
    write("db/schema.rb", %(create_table "users" do |t|\n  t.string "crypted_password"\n  t.string "salt"\nend))

    assert_equal %w[crypted_password salt], updater.old_password_columns
  end

  def test_an_application_that_already_moved_is_left_in_peace
    write("db/schema.rb", %(t.string "password_digest"\nt.string "salt"))

    assert_empty updater.old_password_columns
  end

  # --- what fails without a word ------------------------------------------------

  # A gem that is alive but that moved a piece out of itself. `bundle install`
  # says nothing; the constant fails on the first request that reaches it.
  def test_a_constant_that_moved_to_another_gem_is_found_where_it_is_written
    write("app/controllers/pagos_controller.rb", "  include ActiveMerchant::Billing::Integrations\n")

    assert_equal ["ActiveMerchant::Billing::Integrations"], updater.moved_constants.keys
  end

  # The longer name matches the shorter one too, and the line to write instead
  # is not the same.
  def test_the_longer_name_wins
    write("app/views/pagos/show.dryml", "ActiveMerchant::Billing::Integrations::ActionViewHelper")

    assert_equal ["ActiveMerchant::Billing::Integrations::ActionViewHelper"], updater.moved_constants.keys
  end

  # `config/initializers/constants.rb` is in .gitignore -- it carries keys -- so
  # a checkout has the example and nothing else, and the application boots until
  # the first line that reads one of them.
  def test_an_example_with_no_real_file_beside_it_is_named
    write("config/initializers/constants.rb.example", "SECRET = 'xxx'")
    write("config/database.yml.example", "")
    write("config/database.yml", "")

    assert_equal ["config/initializers/constants.rb.example"],
                 updater.orphan_examples.map { |file| updater.send(:relative, file) }
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

  def rewrite_bootstrap(markup)
    # Tambien en la aplicacion vieja: de ahi se lee **de que version viene**,
    # porque `span5` es Bootstrap 2 y no existe desde la 3.
    write("app/views/x/y.dryml", markup)

    target = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(File.join(target, "app", "views", "x"))
    file = File.join(target, "app", "views", "x", "y.dryml")
    File.write(file, markup)
    updater.send(:write_bootstrap_classes)
    File.read(file)
  ensure
    FileUtils.rm_rf(File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3"))
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

  # Corre el paso de las hojas y devuelve lo que ha quedado escrito, por nombre.
  def resolve_stylesheets
    target = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(File.join(target, "app", "assets", "stylesheets"))
    updater.send(:write_stylesheets)

    Dir[File.join(target, "app", "assets", "stylesheets", "*")].to_h { |file| [File.basename(file), File.read(file)] }
  ensure
    FileUtils.rm_rf(File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3"))
  end

  # Stands in for what `hobo new` leaves behind, so that `write_gemfile` has a
  # skeleton Gemfile to read and to append to.
  def gemfile_after_update(skeleton)
    target = File.join(File.dirname(@directory), "#{File.basename(@directory)}_hobo3")
    FileUtils.mkdir_p(target)
    File.write(File.join(target, "Gemfile"), skeleton)
    updater.send(:write_gemfile)
    File.read(File.join(target, "Gemfile"))
  ensure
    FileUtils.rm_rf(target)
  end

end
