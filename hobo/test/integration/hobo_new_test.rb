require "test_helper"
require "fileutils"
require "tmpdir"
require "net/http"

# `hobo new` from end to end: generate an application, migrate it, and ask it
# for a page.
#
# It builds a whole Rails application and runs bundler, so it takes a couple of
# minutes and does not run by default. It is the only test that checks the thing
# a person actually does first:
#
#   HOBO_TEST_NEW=1 rake test
class HoboNewTest < Minitest::Test

  ROOT = File.expand_path("../../..", __dir__)

  def setup
    skip "lento: ponle HOBO_TEST_NEW=1 para generar una aplicacion de verdad" unless ENV["HOBO_TEST_NEW"]
  end

  def test_hobo_new_leaves_an_application_that_serves_a_derived_page
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "prueba")

      output = new_app(tmp, "prueba")

      assert File.exist?(File.join(app, "config", "environment.rb")), "no se genero la aplicacion:\n#{output}"

      # The model and the controller of the example this suite asked for, and
      # **no views**: those are derived.
      assert File.exist?(File.join(app, "app", "models", "story.rb")), output
      assert File.exist?(File.join(app, "app", "controllers", "stories_controller.rb")), output
      assert_empty Dir[File.join(app, "app", "views", "stories", "*")],
                   "hobo:resource no deberia escribir vistas: las deriva"

      # The migration is written from the model, not by hand: one for Story, and
      # the two Rails' authentication generator brings.
      assert_equal 3, Dir[File.join(app, "db", "migrate", "*.rb")].length, output

      # And it is *run*. `hobo:migration` refuses to work while another
      # generator has left pending migrations, so this used to come out as an
      # application that answered 500 on its first page -- and quietly, because
      # the call was wrapped in `rescue nil`.
      File.write(File.join(app, "tmp", "pending.rb"),
                 "print ActiveRecord::Base.connection_pool.migration_context.needs_migration?")
      pending = run_command(app, "bin/rails runner tmp/pending.rb")

      assert_includes pending, "false", "hobo new deja migraciones sin correr:\n#{pending}"

      File.write(File.join(app, "tmp", "smoke.rb"), <<~RUBY)
        Story.create!(:title => "Hobo 2027", :body => "Sin escribir vistas")
        # The index of the model, not "/": since `hobo:front_page` joined the
        # template, the root of a fresh application is the page that asks for
        # the first user.
        env = Rack::MockRequest.env_for("http://localhost/stories")
        env["action_dispatch.show_exceptions"] = :none
        # Rails blocks a request whose Host it does not recognise, and
        # `env_for` leaves that header empty: the answer is a 403 from the
        # middleware, which looks exactly like a permission denied and is not.
        env["HTTP_HOST"] = "localhost"
        status, _headers, body = Rails.application.call(env)
        html = ""; body.each { |chunk| html << chunk }
        puts "STATUS \#{status}"
        puts html.gsub(/<!--.*?-->/m, "")
      RUBY

      served = run_command(app, "bin/rails runner tmp/smoke.rb")

      assert_includes served, "STATUS 200", served
      assert_includes served, %(<div class="index-page stories">), served
      assert_includes served, "Hobo 2027"
    end
  end

  # The first five minutes, end to end: arrive at an empty application, become
  # its administrator, and then have somebody else make an account.
  #
  # Against a **real server**, because being logged in is a cookie and cookies
  # are the thing that in-process request helpers get subtly wrong: an earlier
  # version of this drove `Rails.application.call` by hand and reported failures
  # the running application did not have. A test that lies in that direction is
  # worse than no test.
  def test_the_first_person_owns_the_application_and_the_next_one_can_sign_up
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "prueba")
      new_app(tmp, "prueba")

      with_server(app) do |http|
        jefe = Browser.new(http)

        # Nobody yet: the application asks for its administrator.
        assert_includes jefe.get("/"), "user[password_confirmation]",
                        "una aplicacion vacia tiene que ofrecer crear el primer usuario"

        jefe.post("/first-user", "user[name]" => "Jefe",
                                 "user[email_address]" => "jefe@example.com",
                                 "user[password]" => "test1234",
                                 "user[password_confirmation]" => "test1234")

        # Created **and** logged in. Rails 8 resumes the session inside
        # `require_authentication`, and this page skips that filter, so it used
        # to end with a new user and a bar that said "Log in".
        home = jefe.get("/")
        assert_includes home, "Log out", "quien crea el primer usuario se queda dentro"
        refute_includes home, "Register administrator",
                        "con usuarios, la portada ya no ofrece crear el administrador"

        # And somebody else can get an account, which is the half Rails'
        # authentication generator does not write.
        otra = Browser.new(http)
        assert_includes otra.get("/signup"), "user[password_confirmation]",
                        "tiene que haber una pagina de alta"

        otra.post("/signup", "user[name]" => "Otra",
                             "user[email_address]" => "otra@example.com",
                             "user[password]" => "test1234",
                             "user[password_confirmation]" => "test1234")

        assert_includes otra.get("/"), "Log out", "quien se da de alta se queda dentro"
      end
    end
  end

  # `hobo new --no-theme`: the question the old setup wizard asked, kept.
  #
  # The theme used to be a fact -- `require "hobo_bootstrap"` at the bottom of
  # hobo.rb, which is to say always, before an application had said anything.
  # With it loaded, `<page>` paints a whole document and the controller skips
  # the application's layout, because a page inside a layout that is also a page
  # gives two of everything. So an application that already had a design, or
  # somebody who wanted to write their own, had no way in.
  #
  # Answer no and Hobo paints **the body** of each page, and the application's
  # own layout wraps it. Everything else -- the derivation, the forms, the
  # permissions -- is the same.
  def test_hobo_new_can_leave_the_design_to_you
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "plana")
      new_app(tmp, "plana", "--no-theme")

      # The application says so out loud, in its own configuration.
      assert_includes File.read(File.join(app, "config", "application.rb")), "config.hobo.theme = false"

      # And its layout is untouched: no stylesheet of Hobo's in it.
      layout = File.read(File.join(app, "app", "views", "layouts", "application.html.erb"))
      refute_includes layout, "bootstrap"
      refute_includes layout, %(stylesheet_link_tag "hobo")

      File.write(File.join(app, "tmp", "seed.rb"),
                 %(Story.create!(:title => "Una historia", :body => "Cuerpo")))
      run_command(app, "bin/rails runner tmp/seed.rb")

      with_server(app, 3098) do |http|
        page = Browser.new(http).get("/stories")

        # One document, and it is the application's -- the title comes from the
        # layout Rails wrote, not from Hobo's theme.
        assert_equal 1, page.scan("<html").length, "dos documentos: la pagina se pinto dentro de otra pagina"
        assert_includes page, "<title>Plana</title>"

        # And the derived page is inside it, doing its job.
        assert_includes page, %(class="index-page stories")
        assert_includes page, "Una historia"
      end
    end
  end

  # `hobo:signup --activation-email`: another of the setup wizard's questions,
  # and the first one built on **lifecycles** (piece 5).
  #
  # The account is created inactive, a mail carries a one-use key, and the key
  # turns it on. The rules live in the user model -- `create :signup ...
  # :new_key => true` and `transition :activate, :available_to => :key_holder` --
  # not in the controller, which is the point of having lifecycles at all.
  def test_signup_can_wait_for_the_mail_to_be_answered
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "activa")
      new_app(tmp, "activa")
      run_command(app, "bin/rails generate hobo:signup --activation-email --force")

      # The lifecycle declares two columns, and the migration generator has to
      # see a model whose only Hobo fields come from a lifecycle.
      migration = run_command(app, "bin/rails generate hobo:migration -n -m")
      assert_includes migration, "add_column :users, :state", migration
      assert_includes migration, "add_column :users, :key_timestamp", migration

      File.write(File.join(app, "tmp", "state.rb"), %(print [User.last&.state, User.last&.id].join(" ")))
      File.write(File.join(app, "tmp", "key.rb"), %(print User.last.lifecycle.key))

      with_server(app, 3097) do |http|
        # The first person in owns the application and is active from the start:
        # they arrive at the front page, before there is anybody to send a mail
        # to or anybody to answer it. Activation is for **everybody after that**,
        # so the test has to make the owner first or it would be measuring the
        # exception.
        jefa = Browser.new(http)
        jefa.get("/")
        jefa.post("/first-user", "user[name]" => "Jefa",
                                 "user[email_address]" => "jefa@example.com",
                                 "user[password]" => "test1234",
                                 "user[password_confirmation]" => "test1234")

        nueva = Browser.new(http)
        nueva.get("/signup")
        nueva.post("/signup", "user[name]" => "Nueva",
                              "user[email_address]" => "nueva@example.com",
                              "user[password]" => "test1234",
                              "user[password_confirmation]" => "test1234")

        state, id = run_command(app, "bin/rails runner tmp/state.rb").split
        assert_equal "inactive", state, "el alta con activacion deja la cuenta apagada"

        # And an account that is off does not get in. The rule is in the model,
        # so it holds wherever the application authenticates.
        intento = Browser.new(http)
        intento.get("/session/new")
        intento.post("/session", "email_address" => "nueva@example.com", "password" => "test1234")
        refute_includes intento.get("/"), "Log out", "sin activar no se entra"

        # The key from the mail. Whoever brings it may take the step.
        key = run_command(app, "bin/rails runner tmp/key.rb")
        con_clave = Browser.new(http)
        con_clave.get("/activate/#{id}?key=#{key}")

        assert_equal "active", run_command(app, "bin/rails runner tmp/state.rb").split.first,
                     "la clave del correo tiene que activar la cuenta"
        assert_includes con_clave.get("/"), "Log out", "y deja dentro a quien activa"

        # A key somebody made up opens nothing.
        File.write(File.join(app, "tmp", "otra.rb"), <<~RUBY)
          User.lifecycle.signup(nil, :email_address => "otra@example.com",
                                     :password => "test1234", :password_confirmation => "test1234")
          print User.last.id
        RUBY
        otro_id = run_command(app, "bin/rails runner tmp/otra.rb")
        inventada = Browser.new(http)
        inventada.get("/activate/#{otro_id}?key=#{'0' * 40}")

        assert_equal "inactive", run_command(app, "bin/rails runner tmp/state.rb").split.first,
                     "una clave inventada no activa nada"
      end
    end
  end

  # `hobo new --invite-only`: the other account question of the old wizard.
  #
  # There is no public signup at all -- the route is not drawn, so the page does
  # not exist and the bar stops offering it by itself. An administrator invites,
  # and the person invited chooses their own password when they accept.
  #
  # The first person in is the administrator: the front page creates them
  # directly, without a lifecycle step, so the model has to put them in the
  # active state as well. Otherwise the first user of a brand new application
  # cannot log in -- a locked door with the key inside.
  def test_hobo_new_can_make_a_site_you_have_to_be_invited_to
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "porinvitacion")
      new_app(tmp, "porinvitacion", "--invite-only")

      refute_includes File.read(File.join(app, "config", "routes.rb")), "registrations#new",
                      "en un sitio por invitacion no hay alta publica"

      File.write(File.join(app, "tmp", "quien.rb"), <<~RUBY)
        print User.order(:id).map { |u| "\#{u.id}:\#{u.email_address}:\#{u.administrator?}:\#{u.state}" }.join(" ")
      RUBY

      with_server(app, 3096) do |http|
        jefa = Browser.new(http)
        jefa.get("/")
        jefa.post("/first-user", "user[name]" => "Jefa",
                                 "user[email_address]" => "jefa@example.com",
                                 "user[password]" => "test1234",
                                 "user[password_confirmation]" => "test1234")

        # In, and the owner of the application.
        assert_includes jefa.get("/"), "Log out", "el primero entra"
        assert_includes run_command(app, "bin/rails runner tmp/quien.rb"), "jefa@example.com:true:active"

        # Nobody else gets in on their own.
        stranger = Browser.new(http)
        refute_includes stranger.get("/"), "Sign up"

        # The administrator invites.
        jefa.get("/invite")
        jefa.post("/invite", "user[email_address]" => "invitada@example.com")
        assert_includes run_command(app, "bin/rails runner tmp/quien.rb"), "invitada@example.com:false:invited"

        # And the link in the mail is where the password is chosen.
        link = File.read(File.join(app, "log", "development.log"))[%r{INVITATION (/accept/\d+\?key=\w+)}, 1]
        refute_nil link, "no se envio la invitacion"

        invitada = Browser.new(http)
        assert_includes invitada.get(link), "Choose a password"
        invitada.post(link, "user[password]" => "otra1234", "user[password_confirmation]" => "otra1234")

        assert_includes run_command(app, "bin/rails runner tmp/quien.rb"), "invitada@example.com:false:active"
        assert_includes invitada.get("/"), "Log out", "quien acepta la invitacion se queda dentro"
      end
    end
  end

  # `hobo:admin_subsite`: the last of the setup wizard's big questions.
  #
  # In Hobo 2 this wrote controllers, a DRYML taglib per subsite, a stylesheet,
  # a JavaScript manifest and a theme. Here it writes **controllers**, because
  # that is all a subsite is now: `Hobo.subsites` is "a directory under
  # app/controllers with a controller in it", `hobo_routes` draws those routes
  # under that prefix, and the pages are the derived ones -- the same model,
  # seen by somebody who is allowed more.
  def test_an_admin_subsite_is_a_directory_of_controllers
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "conadmin")
      new_app(tmp, "conadmin")
      run_command(app, "bin/rails generate hobo:admin_subsite")

      # The field an administrator is made of, and the migration for it.
      assert_includes File.read(File.join(app, "app", "models", "user.rb")), "administrator"
      assert_includes run_command(app, "bin/rails generate hobo:migration -n -m"),
                      "add_column :users, :administrator"

      # Nothing was registered anywhere: the routes come from the directory.
      refute_includes File.read(File.join(app, "config", "routes.rb")), "admin"

      with_server(app, 3095) do |http|
        jefa = Browser.new(http)
        jefa.get("/")
        jefa.post("/first-user", "user[name]" => "Jefa",
                                 "user[email_address]" => "jefa@example.com",
                                 "user[password]" => "test1234",
                                 "user[password_confirmation]" => "test1234")

        assert_includes jefa.get("/admin/stories"), "index-page stories",
                        "una administradora entra en su subsitio"

        # Somebody else does not, and still has the rest of the application.
        otra = Browser.new(http)
        otra.get("/signup")
        otra.post("/signup", "user[name]" => "Otra",
                             "user[email_address]" => "otra@example.com",
                             "user[password]" => "test1234",
                             "user[password_confirmation]" => "test1234")

        otra.get("/admin/stories")
        assert_equal "302", otra.status, "quien no es administrador no entra en /admin"
        assert_includes otra.get("/stories"), "index-page stories", "y el resto del sitio le funciona igual"
      end
    end
  end

  # `hobo new --private`: "prevent all access to the site to non-members", as the
  # old wizard asked it.
  #
  # Rails' `require_authentication` is already on every controller. What Hobo
  # does is step around it, on purpose, so that a public page stays public and
  # the model's permissions decide page by page. This is the application saying
  # it does not want that: the filter stays.
  #
  # And the door still works, which is the part worth a test: the front page,
  # the session and the signup let a stranger in, because those pages allow
  # anonymous access themselves. A private site whose first user cannot be
  # created is a locked building with the key inside.
  def test_hobo_new_can_put_the_whole_site_behind_the_login
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "privada")
      new_app(tmp, "privada", "--private")

      assert_includes File.read(File.join(app, "config", "application.rb")), "config.hobo.private_site = true"

      with_server(app, 3094) do |http|
        stranger = Browser.new(http)

        stranger.get("/stories")
        assert_equal "302", stranger.status, "un desconocido no ve las paginas de un sitio privado"

        # The way in is still there.
        stranger.get("/session/new")
        assert_equal "200", stranger.status, "la pagina de entrar tiene que abrirse"

        # Asked last on purpose: the token this browser sends is the one of the
        # page it is standing on.
        assert_includes stranger.get("/"), "user[password_confirmation]", "la portada tiene que dejar crear el primer usuario"
        stranger.post("/first-user", "user[name]" => "Jefa",
                                     "user[email_address]" => "jefa@example.com",
                                     "user[password]" => "test1234",
                                     "user[password_confirmation]" => "test1234")

        assert_includes stranger.get("/stories"), "index-page stories", "y dentro se ve todo"
      end
    end
  end

  # `hobo new --search`: the box in the bar that looks in every model.
  #
  # The engine is Hobo 2's and untouched -- `Hobo.find_by_search` asks every
  # model that declares search columns, or that has one of the ones Hobo guesses
  # (name, title, body, description). What this checks is the loop: type in the
  # bar, land on a page, and find the thing.
  def test_hobo_new_can_search_the_whole_site
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "buscadora")
      new_app(tmp, "buscadora", "--search")

      File.write(File.join(app, "tmp", "seed.rb"), <<~RUBY)
        Story.create!(:title => "Historia de gatos", :body => "Maullidos")
        Story.create!(:title => "Otra cosa", :body => "Perros")
      RUBY
      run_command(app, "bin/rails runner tmp/seed.rb")

      with_server(app, 3093) do |http|
        page = Browser.new(http)

        # The box is in the bar of every page, because the route exists.
        index = page.get("/stories")
        assert_includes index, %(name="query"), "la barra tiene que ofrecer la busqueda"

        found = page.get("/search?query=gatos")
        assert_includes found, "Historia de gatos"
        refute_includes found, "Otra cosa", "la busqueda no puede traer lo que no coincide"

        assert_includes page.get("/search?query=zzzz"), "Nothing matched"
      end
    end
  end

  # A browser: a cookie jar and the authenticity token of the page it is on.
  class Browser

    def initialize(http)
      @http = http
      @cookies = {}
    end

    attr_reader :status

    def get(path)
      request = Net::HTTP::Get.new(path)
      @body = send_request(request)
    end

    def post(path, params)
      request = Net::HTTP::Post.new(path)
      request.set_form_data(params.merge("authenticity_token" => token))
      body = send_request(request)
      # A form that works answers with a redirect; one that does not answers
      # with itself, and the assertion afterwards would blame the wrong thing.
      raise "el formulario de #{path} no redirigio:\n#{body[0, 500]}" unless @status.start_with?("30")
      body
    end

    private

    def token = @body.to_s[/name="authenticity_token" value="([^"]+)"/, 1]

    def send_request(request)
      request["Cookie"] = @cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
      response = @http.request(request)
      @status = response.code
      Array(response.get_fields("set-cookie")).each do |cookie|
        name, value = cookie.split(";").first.split("=", 2)
        @cookies[name] = value
      end
      response.body.to_s
    end

  end

  # Boots the generated application, waits for it to answer, and takes it down.
  def with_server(app, port = 3099)
    pid = unbundled do
      spawn({ "HOBODEV" => ROOT }, "bin/rails server -p #{port} -b 127.0.0.1",
            :chdir => app, [:out, :err] => File.join(app, "log", "server.log"))
    end
    http = Net::HTTP.new("127.0.0.1", port)

    up = 60.times.any? do
      sleep 1
      begin
        http.start
        true
      rescue StandardError
        false
      end
    end
    raise "la aplicacion generada no arranco:\n#{File.read(File.join(app, 'log', 'server.log'))}" unless up

    yield http
  ensure
    http&.finish if http&.started?
    Process.kill("TERM", pid) if pid
    Process.wait(pid) if pid
  end

  private

  # `< /dev/null` is not decoration. A Rails generator that asks a question --
  # `hobo:migration` asks DROP/RENAME/KEEP when it cannot tell what a column
  # became -- reads standard input, and in a test there is nobody there: the
  # command waits **for ever**, and what you see is a suite that hangs rather
  # than a suite that fails. Twenty minutes of "it must be slow".
  #
  # And `with_unbundled_env`, which cost an evening: run this suite with
  # `bundle exec` and BUNDLE_GEMFILE points at **this gem's** Gemfile. The
  # `bundle install` inside `rails new` obeys it, installs this gem's
  # dependencies a second time and leaves the generated application without a
  # Gemfile.lock and without propshaft. What fails then is a page, much later,
  # with `undefined method 'assets'` -- and nothing points back here.
  def run_command(dir, command)
    unbundled { `cd #{dir} && HOBODEV=#{ROOT} #{command} < /dev/null 2>&1` }
  end

  # Everything of Rails that this suite does not need, and takes minutes to
  # install.
  RAILS_FLAGS = "--skip-git --skip-test --skip-system-test --skip-javascript " \
                "--skip-hotwire --skip-jbuilder --skip-action-cable " \
                "--skip-action-mailbox --skip-action-text --skip-active-storage " \
                "--skip-bootsnap".freeze

  # `hobo new`, and then the model these tests show pages of.
  #
  # It used to come out of the generator -- "one worked example" -- and it does
  # not any more: **Hobo 2 never wrote a model nobody had asked for**, and this
  # one turned up before the wizard had asked its first question, so what went
  # past on screen was a user model, a question about a migration, and a `Story`
  # appearing inside it. The example belongs to whoever wants an example, which
  # here is the tests.
  def new_app(tmp, name, flags = "")
    output = run_command(tmp, "#{ROOT}/hobo/bin/hobo new #{name} #{flags} #{RAILS_FLAGS}")
    app = File.join(tmp, name)

    # Checked here, on every application this suite builds, because it is the
    # only moment it can be checked: what comes out of `hobo new` are Rails'
    # four models and not a fifth.
    assert_equal %w[application_record.rb current.rb session.rb user.rb],
                 Dir[File.join(app, "app", "models", "*.rb")].map { |f| File.basename(f) }.sort,
                 "hobo new no deberia escribir modelos propios:\n#{output}"

    output + run_command(app, "bin/rails generate hobo:resource story title:string body:text published_on:date") +
      run_command(app, "bin/rails generate hobo:migration -n -m")
  end

  def unbundled(&block)
    defined?(Bundler) ? Bundler.with_unbundled_env(&block) : block.call
  end

end
