require "minitest/autorun"
require "fileutils"

# What a Hobo application must be, checked in a browser, against a real one.
#
# ---------------------------------------------------------------------------
# Why this file exists
# ---------------------------------------------------------------------------
#
# Every other test in this repository checks a piece against what that piece was
# built to do: <view> paints a value, <page> declares its params, the derivation
# engine reads a model. All of them passed while the application looked like
# nothing at all -- no stylesheet, no links, the theme built and never connected.
#
# The reason is simple and worth writing down: **a test written from the code
# cannot see an absence.** Nobody had written "a card links to its record", so
# nothing failed when no card did.
#
# So these come from somewhere else: from what the old Hobo *did*, which is
# still in this repository -- `integration_tests/agility_bootstrap/test`, and in
# particular `integration/create_account_test.rb`, which is where the first-user
# flow is specified. They are properties of the assembled product, not of any
# piece, and they are written to fail when something is missing rather than
# wrong.
#
#   cd hobo && rake test:app                # the bench
#   HOBO_APP=/tmp/hobo_luz rake test        # point it at a generated application
class AppConformanceTest < Minitest::Test

  APP = ENV["HOBO_APP"]

  def setup
    skip "ponle HOBO_APP=/ruta/a/una/app generada con `hobo new`" if APP.nil?
    skip @@why_not if defined?(@@why_not) && @@why_not

    begin
      require "capybara"
      require "selenium-webdriver"
    rescue LoadError => e
      @@why_not = "falta una gema del banco de navegador (#{e.message})"
      skip @@why_not
    end

    @page = self.class.session
  end

  def self.session
    @session ||= begin
      Capybara.register_driver(:hobo_conformance) do |app|
        options = Selenium::WebDriver::Firefox::Options.new
        options.add_argument("-headless")
        Capybara::Selenium::Driver.new(app, :browser => :firefox, :options => options)
      end
      Capybara.app_host = ENV["HOBO_APP_URL"] || "http://localhost:3007"
      Capybara.run_server = false
      Capybara::Session.new(:hobo_conformance)
    end
  end

  Minitest.after_run { @session&.driver&.quit }

  # --- the page is a page -----------------------------------------------------

  # A page with two <html> is a page inside another page, which is what happens
  # when a theme that paints a whole document is also wrapped in a layout.
  # (The doctype is not checked here: the browser hands back a serialised DOM,
  # not the bytes, so it is checked where the bytes are -- in the integration
  # test of hobo_rapid.)
  def test_the_index_is_one_document
    @page.visit("/")

    assert_equal 1, @page.html.scan("<html").length
  end

  # A theme that is not served is a theme that does not exist. This is the one
  # that would have caught the whole afternoon.
  def test_the_stylesheets_are_actually_served
    @page.visit("/")

    hrefs = @page.all("link[rel=stylesheet]", :visible => :all).map { |link| link[:href] }
    refute_empty hrefs, "la pagina no enlaza ninguna hoja de estilo"

    hrefs.each do |href|
      @page.visit(href)
      # A stylesheet that answers with the application's 404 page instead of css
      # is the failure this is looking for.
      refute_includes @page.title.to_s, "404", "la hoja #{href} no se sirve"
      assert_operator @page.html.length, :>, 500, "la hoja #{href} llega vacia"
    end
  end

  def test_the_page_is_styled_by_bootstrap
    @page.visit("/")

    assert @page.has_css?("nav.navbar", :visible => :all), "falta la barra de navegacion del tema"
    assert @page.has_css?(".container", :visible => :all), "falta el contenedor del tema"
  end

  # The pages Rails renders -- the session form, the password pages -- go
  # through `app/views/layouts/application.html.erb`, and `hobo new` is what
  # puts the theme into it. It does that by rewriting one line, and Rails keeps
  # changing that line: 8.1 writes `stylesheet_link_tag :app, "data-turbo-track":
  # "reload"`, and the pattern anchored on `:app %>` quietly stopped matching.
  # `gsub_file` reports the file whether or not anything matched, so nothing said
  # a word and half the application went back to looking unstyled.
  def test_the_layout_wears_the_theme
    layout = File.join(APP, "app", "views", "layouts", "application.html.erb")
    skip "no hay layout de aplicacion en #{APP}" unless File.exist?(layout)
    erb = File.read(layout)

    assert_includes erb, %(stylesheet_link_tag "bootstrap"), "el layout no carga el tema"
    assert_includes erb, %(stylesheet_link_tag "hobo"), "el layout no carga hobo.css"
    assert_includes erb, %(class="container), "el layout no trae el contenedor del tema"
  end

  # A page Rails renders in its own layout has to render at all. Hobo reopens
  # ActionView (`hobo/extensions/`), and a patch that is wrong for Rails does
  # not break Hobo's pages -- it breaks these, which no test of a Hobo tag ever
  # visits. `/session/new` came from `bin/rails generate authentication`.
  def test_the_pages_rails_renders_still_render
    @page.visit("/session/new")

    refute_match(/Error|Exception/i, @page.title.to_s, "la pagina de sesion de Rails revienta")
    assert @page.has_css?("input[type=password]", :visible => :all),
           "la pagina de sesion no trae el formulario"
  end

  # The pages Hobo paints are not rendered in the application's layout -- the
  # theme paints the whole document -- so they have to load the application's
  # JavaScript themselves, and for a long time they did it wrong: a plain
  # `<script src="application.js">`, when the entry point is an ES module that
  # needs the import map to resolve its bare imports. It died on its first
  # `import`, silently, and **not one Stimulus controller ran on any page Hobo
  # painted**. The pages Rails renders were fine, which is exactly why nobody
  # saw it.
  #
  # Checked by asking the browser, not by reading the markup: Stimulus either
  # started or it did not.
  def test_the_javascript_runs_on_the_pages_hobo_paints
    skip "esta aplicacion no usa import maps" unless File.exist?(File.join(APP, "config", "importmap.rb"))
    @page.visit("/stories")

    started = @page.evaluate_script("!!(window.Stimulus || document.querySelector('script[type=importmap]'))")
    assert started, "la pagina derivada no carga el javascript de la aplicacion"
  end

  # --- you can get around ------------------------------------------------------

  def test_the_navigation_links_to_the_models
    @page.visit("/")

    links = @page.all("nav a", :visible => :all).map(&:text).map(&:strip).reject(&:empty?)
    assert_includes links, "Stories", "la navegacion no lleva a ninguna parte: #{links.inspect}"
  end

  # A list nobody can click is a list nobody can use.
  #
  # It looks at the index, not at `/`: the front page is the first-user page,
  # and layer 5 turned the index back into a table, so what has to be true is
  # about the *list*, whatever shape it takes -- the record's name leads
  # somewhere.
  def test_each_record_links_to_itself
    @page.visit("/stories")

    links = @page.all("a[href*='/stories/']", :visible => :all)
                 .reject { |link| link[:href].to_s.match?(%r{/stories/new}) }
    refute_empty links, "la lista no enlaza a ningun registro"

    links.first.click
    assert_operator @page.current_path, :match?, %r{/stories/\d+}, "el enlace no lleva a la ficha"
  end

  def test_a_record_page_shows_the_record
    @page.visit("/stories")
    link = @page.all("a[href*='/stories/']", :visible => :all)
                .reject { |l| l[:href].to_s.match?(%r{/stories/new}) }.first
    name = link.text.strip
    link.click

    assert_includes @page.text, name
  end

  # --- the form ----------------------------------------------------------------

  def test_the_new_page_offers_an_input_for_every_field
    @page.visit("/stories/new")

    assert @page.has_css?("input[name='story[title]']", :visible => :all), "falta el campo del nombre"
    assert @page.has_css?("textarea[name='story[body]'], input[name='story[body]']", :visible => :all)
    assert @page.has_css?("input[name='story[published_on]'][type=date]", :visible => :all),
           "una fecha tiene que salir como control de fecha"
  end

  # --- what a card is about ----------------------------------------------------

  def test_a_card_is_about_the_record_and_not_the_database
    @page.visit("/stories")

    refute_includes @page.text, "Created at", "los timestamps no son resumen"
    refute_includes @page.text, "Updated at"
  end

  # --- the first user ----------------------------------------------------------
  #
  # From integration_tests/agility_bootstrap/test/integration/create_account_test.rb:
  # a fresh application offers to create the first administrator. It is the
  # first thing a person sees, and it is what makes the application usable
  # without a console.

  def test_a_fresh_application_offers_to_create_the_first_user
    skip "necesita una aplicacion sin usuarios" unless ENV["HOBO_APP_FRESH"]
    @page.visit("/")

    assert @page.has_button?("Register Administrator") || @page.has_content?("administrator"),
           "una aplicacion recien creada tiene que ofrecer crear el primer usuario"
  end

end
