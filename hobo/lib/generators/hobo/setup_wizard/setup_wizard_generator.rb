require "rails/generators"
require "generators/hobo/user_options"
require "hobo/plugins"
require "hobo_rapid/translation"
require "fileutils"

module Hobo
  module Generators

    # `rails generate hobo:setup_wizard`
    #
    # The questions, and doing what they say. **In an application that already
    # exists**, which is the half that was missing: until now they were only
    # asked while `hobo new` was building one, and the person who most needs
    # them is somebody who has just added the gem to an application of their own.
    #
    # It is the same wizard Hobo 2 had, minus what made it tiring:
    #
    #   - it is **one place that asks**, and `hobo new` calls it too, so the
    #     questions cannot drift apart from the answers
    #   - every question is a flag, so a script never stops
    #   - with no terminal to ask in, every question takes its default
    #   - and it **does not redo what is already there**: run it twice and the
    #     second time it says so instead of writing a second front page
    #
    # What it does not ask any more is what nothing can configure: the jQuery-UI
    # themes (there is no jQuery UI), the DRYML-only templates (both kinds work
    # at once), and whether git should ignore the generated files (nothing is
    # generated).
    #
    # And the search box is not a question either, because it was not one in
    # Hobo 2: every application got `/search` and the box in the bar without
    # being asked. `--no-search` still takes it away.
    class SetupWizardGenerator < Rails::Generators::Base

      include UserOptions

      class_option :theme, :type => :string,
                   :desc => "clean (el que viene dentro), none, o el de una gema instalada"
      class_option :behaviour, :type => :string,
                   :desc => "stimulus (el que viene dentro), o el de una gema instalada"
      class_option :plugins, :type => :array,
                   :desc => "Los demas plugins que quieres, p.ej. --plugins jquery_ui"
      class_option :admin, :type => :boolean,
                   :desc => "Un subsitio de administracion"
      class_option :admin_name, :type => :string,
                   :desc => "Como se llama el subsitio de administracion"
      class_option :admin_theme, :type => :string,
                   :desc => "El tema del subsitio, si quieres otro"
      class_option :search, :type => :boolean,
                   :desc => "La caja de busqueda de la barra (--no-search para quitarla)"

      class_option :private, :type => :boolean,
                   :desc => "Todo el sitio detras del login"
      class_option :locales, :type => :array,
                   :desc => "Los idiomas de la aplicacion, p.ej. --locales en es"
      class_option :locale, :type => :string,
                   :desc => "El idioma por defecto"
      class_option :front, :type => :string,
                   :desc => "Como se llama el controlador de la portada"
      class_option :skip_migration, :type => :boolean,
                   :desc => "No tocar la base de datos"
      class_option :generate_migration, :type => :boolean,
                   :desc => "Escribir la migracion inicial pero no aplicarla"
      class_option :git, :type => :boolean,
                   :desc => "Dejar el trabajo en un commit"
      class_option :wizard, :type => :boolean,
                   :desc => "Preguntar siempre (--no-wizard: no preguntar nunca)"

      # --- the questions --------------------------------------------------------

      def ask_the_questions
        say "\nHobo\n", :green if interactive?

        @theme = choose_theme
        @behaviour = choose_behaviour
        @extras = choose_extras
        @invite_only = yes_or_no?(:invite_only,
                                  "Solo se entra por invitacion? (un administrador invita; no hay alta publica)", false)
        @activation_email = @invite_only ? false : yes_or_no?(:activation_email, "El alta tiene que confirmarse por correo?", false)
        @admin = yes_or_no?(:admin, "Quieres un subsitio de administracion?", false)
        @admin_name = @admin ? named(:admin_name, "Como se llama el subsitio de administracion?", "admin") : "admin"
        @private = yes_or_no?(:private, "Todo el sitio detras del login? (si no, cada modelo decide quien ve sus paginas)", false)
        @front = named(:front, "Como se llama el controlador de la portada?", "front")
        # En este orden porque es el de Hobo 2: la base de datos antes que los
        # idiomas, y los idiomas antes que git. Se contesta aquí y se hace al
        # final, que es lo que hacía aquel: la pregunta va con las preguntas y el
        # trabajo con el trabajo.
        @migration = choose_migration
        @locales, @locale = choose_locales
        @git = yes_or_no?(:git, "Dejo el trabajo en un commit de git?", false)

        # Not a question: Hobo 2 gave every application `/search` and the box in
        # the bar without asking, and taking it away turned out to be a change
        # nobody had asked for.
        @search = options[:search] != false
      end

      # --- what the answers mean -------------------------------------------------

      # Lo que se ha elegido y no viene dentro **se instala**, que es lo que
      # significa ser un plugin: la gema en el Gemfile es la instalacion
      # (decision 22). Hobo 2 hacia esto mismo -- elegias bootstrap y te anadia
      # `gem "hobo_bootstrap"`.
      #
      # `clean` y `stimulus` no pasan por aqui porque son los de Hobo y vienen
      # dentro. Del resto, cada uno sabe de donde sale: del arbol de trabajo si
      # se esta escribiendo, y de rubygems si no.
      def the_plugin_gems
        chosen_plugins.each do |plugin|
          next say("  el Gemfile ya lleva #{plugin.gem_name}") if
            File.read(File.join(destination_root, "Gemfile")).include?(plugin.gem_name)

          say_step "El plugin #{plugin.name}"
          plugin.path ? gem(plugin.gem_name, :path => plugin.path) : gem(plugin.gem_name)
          @installed_something = true
        end
      end

      # Y se instala aqui mismo, no al final.
      #
      # Todo lo que viene despues arranca `bin/rails` en otro proceso -- la
      # migracion, la portada -- y un Gemfile con una gema que no esta instalada
      # hace que Bundler pare ese proceso antes de empezar. Lo que se veia era el
      # asistente quejandose de la base de datos por una gema que acababa de
      # anadir el mismo.
      def the_bundle
        return unless @installed_something

        inside(destination_root) { run "bundle install" }
      end

      def write_the_configuration
        say_step "La configuracion"
        add_to_configuration "config.hobo.theme = #{@theme == "none" ? "false" : ":#{@theme}"}"
        add_to_configuration "config.hobo.private_site = true" if @private
        add_to_configuration "config.i18n.default_locale = :#{@locale}" unless @locale == "en"
        # Rails only loads the default language unless it is told the others
        # exist, and `I18n.locale = :es` on an application that never declared
        # :es raises. A second language is only a second language once this says
        # so.
        add_to_configuration "config.i18n.available_locales = #{@locales.map(&:to_sym).inspect}" if @locales.size > 1
      end

      # The pages Rails renders -- its session form, its password pages -- go
      # through the application's own layout, and that layout knows nothing
      # about the theme. Without this half the application looks like two
      # applications.
      def dress_the_layout
        return if @theme == "none"
        layout = "app/views/layouts/application.html.erb"
        return say("  (no hay #{layout}: el tema solo vestira las paginas de Hobo)", :yellow) unless
          File.exist?(File.join(destination_root, layout))

        # Que hojas de estilo pide el tema **lo dice el tema**, en su gemspec:
        #
        #   s.metadata["hobo_plugin_stylesheets"] = "bootstrap hobo"
        #
        # Aqui habia `@theme == "bootstrap" ? %w[bootstrap hobo] : %w[clean]`, y
        # era el ultimo sitio de Hobo donde estaba escrito el nombre de un tema.
        sheets = theme_plugin&.stylesheets || [@theme]
        return say("  el layout ya lleva el tema") if File.read(File.join(destination_root, layout)).include?(%(stylesheet_link_tag "#{sheets.first}"))

        links = sheets.map { |s| %(<%= stylesheet_link_tag "#{s}" %>) }.join("\n\\1")
        gsub_file layout, /^(\s*)<%= stylesheet_link_tag :app.*%>$/, "\\1#{links}\n\\0"
        gsub_file layout, /<%= yield %>/, "<div class=\"container\">\n      <%= yield %>\n    </div>"
      end

      # One file per language, which is what having more than one language means.
      def a_place_for_your_own_words
        @locales.each do |locale|
          next if File.exist?(File.join(destination_root, "config/locales/app.#{locale}.yml"))

          create_file "config/locales/app.#{locale}.yml", <<~YAML
            # The names your application uses for its own things. Rails looks here for
            # them, and Hobo's pages ask Rails -- so a model called `Story` becomes
            # "Relato" everywhere by saying it once, here.
            #
            # Hobo's own strings are in the gem; to change one, write the same key in
            # a file of yours (config/locales/hobo.#{locale}.yml).
            #{locale}:
            #  activerecord:
            #    models:
            #      story:
            #        one: Story
            #        other: Stories
          YAML
        end

        # Hobo ships its own words in English and Spanish. Any other language is
        # the application's to write, and saying so now is cheaper than a page
        # that comes out half translated.
        untranslated = @locales - HoboRapid::TRANSLATED_LOCALES
        say("  Hobo no habla #{untranslated.join(', ')}: sus botones saldran en ingles hasta que escribas " \
            "config/locales/hobo.#{untranslated.first}.yml", :yellow) if untranslated.any?
      end

      def draw_the_routes
        return if routes.include?("hobo_routes")
        route "hobo_routes"
      end

      def the_front_page
        say_step "La portada"
        return say("  ya hay una portada (root)") if routes.match?(/^\s*root /)
        invoke "hobo:front_controller", [@front]
      end

      def the_accounts
        say_step "Las cuentas"
        return say("  no hay modelo de usuario: corre `bin/rails generate authentication`", :yellow) unless user_exists?
        return say("  ya hay alta") if routes.match?(/signup|invite/)

        invoke "hobo:user_resource", ["User"],
               :activation_email => @activation_email, :invite_only => @invite_only
      end

      # Run again and it picks up the models that appeared since: a subsite is a
      # controller per resource, and resources arrive over time. Thor says
      # "identical" for the ones already there.
      def the_search
        return unless @search
        say_step "La busqueda"
        return say("  ya hay busqueda") if routes.include?("site_search")
        invoke "hobo:search"
      end

      def the_admin_subsite
        return unless @admin
        say_step "El subsitio de administracion"
        invoke "hobo:admin_subsite", [@admin_name], :theme => options[:admin_theme]
      end

      # La base de datos, **entera y en una sola pregunta**.
      #
      # Hobo 2 preguntaba por la migración inicial y era la pregunta correcta:
      # lo que el asistente acaba de escribir -- un lifecycle, la columna de
      # administrador -- son columnas que la base no tiene, y una aplicación que
      # arranca sin ellas falla en su primera página.
      #
      # Lo que costó tres intentos es *cuándo* y *sobre qué*:
      #
      #   - preguntarlo con el resto de las preguntas era preguntar antes de
      #     saber si haría falta: en una aplicación sin banderas no hace falta,
      #     y la respuesta se ganaba un «nada que cambiar» inmediato
      #   - y no era la única cosa que tocaba la base: `hobo new` aplicaba por su
      #     cuenta las dos migraciones del generador de autenticación de Rails,
      #     así que lo que se veía era una migración ejecutándose sola y, detrás,
      #     una pregunta sobre otra que ya no tenía nada que hacer
      #
      # Así que es una sola: lo que falta -- lo de Rails y lo de Hobo -- y qué
      # hacer con ello. Y cuando lo de Hobo se escribe, se escribe con el `up` y
      # el `down` delante, porque nadie decide sobre algo que no ha visto.
      def the_migration
        return say_how_to_do_it_later if @migration == :skip

        the_migrations_rails_wrote

        return say("\n  La base de datos ya esta al dia.\n") unless anything_to_migrate?

        say_step "La migracion"

        # In another process, and this is the whole reason `hobo new` used to
        # call it from the template: **the models this wizard has just written
        # are on disk, not in memory**. `User` was loaded before the wizard
        # taught it a lifecycle, so an `invoke` from here reads the class as it
        # was and reports "nothing to change" about columns that are missing.
        # A new process reads the files -- and it is also what lets the
        # generator have the terminal to ask its own question.
        inside(destination_root) { run "bin/rails generate hobo:migration #{migration_flags}".strip }
      end

      # The other question Hobo 2 asked at the end. `rails new` leaves a
      # repository behind, but everything this wizard wrote came after it, so
      # without this the first commit of the application does not contain the
      # application.
      def the_git_repository
        return unless @git
        say_step "El repositorio"

        inside(destination_root) do
          run "git init -q", :capture => true unless File.directory?(File.join(destination_root, ".git"))
          run "git add -A", :capture => true
          # `--no-verify` and no author: whatever the machine is set up with. A
          # generator that signs commits with a name nobody chose is a generator
          # that gets uninstalled.
          run %(git commit -q --no-verify -m "Aplicacion creada con Hobo"), :capture => true
        end
      end

      private

      # Los plugins que hay que instalar: los elegidos que no vienen dentro.
      # `clean`, `stimulus` y `none` no son gemas.
      def chosen_plugins
        ([@theme, @behaviour] + Array(@extras)).compact.filter_map do |name|
          Hobo::Plugins.all.find { |plugin| plugin.name == name }
        end
      end

      # El Gemfile, o nada: el asistente tiene que poder responder sus preguntas
      # tambien donde no hay aplicacion, que es como lo prueban sus pruebas.
      def gemfile
        @gemfile ||= File.read(File.join(destination_root, "Gemfile"))
      rescue StandardError
        ""
      end

      def theme_plugin = Hobo::Plugins.of(:theme).find { |plugin| plugin.name == @theme }

      def interactive?
        return true if options[:wizard]
        return false if options[:wizard] == false
        $stdin.tty?
      end

      # The parentheses matter: in an endless method `def x = y if z` the `if`
      # applies to the **definition**, so this ran `interactive?` at class level
      # and the generator would not even load.
      def say_step(title) = (say("\n#{title}", :green) if interactive?)

      # Thor's `yes?` reads a bare Enter as "no", which makes a question whose
      # default is yes impossible to answer the easy way. This reads the Enter
      # as the default, which is what the brackets promise.
      def yes_or_no?(flag, text, default)
        given = options[flag]
        return given unless given.nil?
        return default unless interactive?

        said = ask("#{text} [#{default ? 'S/n' : 's/N'}]").to_s.strip.downcase
        said.empty? ? default : said.start_with?("s", "y")
      end

      def named(flag, text, default)
        given = options[flag]
        return given if given.present?
        return default unless interactive?

        said = ask("#{text} [#{default}]").to_s.strip
        said.empty? ? default : said
      end

      # El tema, y **la lista no esta escrita aqui**.
      #
      # Estaba: `[c]lean, [b]ootstrap, [n]inguno`, con lo que un tema que no
      # fuera de Hobo no existia para el asistente por muy instalado que
      # estuviera. Ahora las respuestas son las gemas que se han encontrado
      # (Hobo::Plugins), mas `clean`, que viene dentro, y `none`, que no es un
      # tema sino la respuesta de quien tiene su propio layout.
      def choose_theme
        answers = [["clean", "el que trae Hobo"]] +
                  Hobo::Plugins.of(:theme).map { |plugin| [plugin.name, plugin.describe] } +
                  [["none", "ninguno: tu layout, tus hojas de estilo"]]

        choose(:theme, "El tema:", answers, "clean")
      end

      # Y quien ejecuta el comportamiento que las paginas describen -- el `+` de
      # un formulario, el desplegable que abre un campo nuevo.
      #
      # No se pregunto nunca hasta ahora porque no habia nada que elegir. La
      # pregunta aparece **sola** el dia que hay una gema que se ofrece: con
      # solo Stimulus no se pregunta, porque una pregunta con una respuesta no
      # es una pregunta, es un tramite.
      #
      # Y no hay opcion de "ninguno", igual que en Hobo 2: un formulario sin
      # comportamiento es un formulario al que le faltan la mitad de las cosas,
      # y eso no es una eleccion, es una averia.
      def choose_behaviour
        answers = [["stimulus", "el que trae Rails, y viene dentro de Hobo"]] +
                  Hobo::Plugins.of(:behaviour).map { |plugin| [plugin.name, plugin.describe] }

        choose(:behaviour, "Quien ejecuta el comportamiento de las paginas:", answers, "stimulus")
      end

      # Y los demas plugins que haya instalados: los que no compiten por nada.
      #
      # El tema es uno y quien ejecuta el comportamiento tambien, asi que son
      # preguntas de elegir. Un plugin que solo trae tags -- `hobo_jquery_ui`,
      # con su calendario -- no compite con ninguno, asi que es un si o un no
      # por cada uno, y por defecto no: tener una gema instalada no es haberla
      # pedido, y muchas veces es solo una dependencia de otra.
      def choose_extras
        # `--plugins jquery_ui timeago` y `--plugins=jquery_ui,timeago` son la
        # misma respuesta, como en los idiomas.
        given = Array(options[:plugins]).flat_map { |p| p.to_s.split(/[\s,]+/) }.reject(&:empty?)
        return given if given.any?
        return [] if options[:plugins]

        Hobo::Plugins.of(:tags).filter_map do |plugin|
          next if gemfile.include?(plugin.gem_name)
          plugin.name if yes_or_no?(:"plugin_#{plugin.name}",
                                    "Instalar #{plugin.gem_name}? (#{plugin.describe})", false)
        end
      end

      # Una pregunta cuyas respuestas se saben al preguntarla y no al escribirla.
      #
      # Numerada y no por letras: `[c]lean, [b]ootstrap` funcionaba porque la
      # lista era fija, y con dos gemas que empiecen por la misma letra deja de
      # funcionar. Vale el numero o el nombre entero.
      def choose(flag, title, answers, default)
        given = options[flag]
        return given if given.present?
        # Una sola respuesta no se pregunta.
        return default if answers.size == 1 || !interactive?

        say "\n#{title}"
        answers.each_with_index do |(name, describe), i|
          say "  #{i + 1}. #{name}#{" -- #{describe}" if describe.present?}"
        end

        said = ask("Cual? [#{default}]").to_s.strip.downcase
        return default if said.empty?

        names = answers.map(&:first)
        return names[said.to_i - 1] if said.to_i.between?(1, names.size)
        names.include?(said) ? said : default
      end

      # The languages, and which of them is the default -- one question when
      # there is one answer, two when there are more, which is how Hobo 2 asked
      # it. `--locale=es` on its own still means "Spanish and only Spanish".
      def choose_locales
        # `--locales en es` and `--locales=en,es` are the same answer.
        given = Array(options[:locales]).flat_map { |l| l.to_s.split(/[\s,]+/) }.reject(&:empty?)
        given = [options[:locale].to_s] if given.empty? && options[:locale].present?

        if given.empty? && interactive?
          said = ask("Idiomas de la aplicacion, separados por espacios? " \
                     "(Hobo habla #{HoboRapid::TRANSLATED_LOCALES.join(' y ')}) [en]").to_s
          given = said.split(/[\s,]+/).reject(&:empty?)
        end
        given = ["en"] if given.empty?

        [given, choose_default_locale(given)]
      end

      def choose_default_locale(locales)
        return locales.first if locales.size == 1
        given = options[:locale]
        return given if given.present? && locales.include?(given.to_s)
        return locales.first unless interactive?

        said = ask("Cual es el idioma por defecto? [#{locales.first}]").to_s.strip
        locales.include?(said) ? said : locales.first
      end

      # Hobo 2's `[s]kip, [g]enerate, [m]igrate`, in its own place: after the
      # front page and before the languages, which is where that wizard asked
      # it. The three answers are also flags, so a script never stops.
      def choose_migration
        return :skip if options[:skip_migration]
        return :generate if options[:generate_migration]
        return :migrate unless interactive?

        said = ask("La migracion inicial: [s]altarla, solo [e]scribirla, escribirla y [a]plicarla? [a]").to_s.strip.downcase
        { "s" => :skip, "e" => :generate }.fetch(said[0].to_s, :migrate)
      end

      # Ya está contestado arriba, así que el generador no vuelve a preguntar:
      # enseña la migración -- que es lo que había que ver -- y hace lo que se le
      # dijo. Es exactamente lo que hacía el asistente de Hobo 2.
      def migration_flags = @migration == :generate ? "-n -g" : "-n -m"

      # Whether the database and the models differ at all. It is the same
      # question `hobo:migration` answers with "Database and models match --
      # nothing to change", asked before bothering anybody with it.
      #
      # If it cannot be answered -- no models loaded, no connection -- the
      # answer is yes: better one question too many than a column that never
      # gets created.
      # Las migraciones que escribió Rails y nadie ha aplicado -- las de `users`
      # y `sessions`, casi siempre.
      #
      # No se pregunta por ellas: la pregunta ya está hecha, y `hobo new` no
      # tocaba la base de datos hasta aquí. Se enseñan por su nombre antes de
      # aplicarlas, que es lo que faltaba: lo que se veía era una migración
      # ejecutándose sola, sin haber preguntado nada.
      #
      # Y van primero porque **`hobo:migration` se niega a trabajar mientras
      # haya migraciones sin aplicar**: sin esto lo que salía era una aplicación
      # cuya primera página contestaba 500 con «no such table».
      def the_migrations_rails_wrote
        pending = pending_migrations
        return if pending.empty?

        say_step "La base de datos"
        say "\n  Aplicando lo que escribio Rails:"
        pending.each { |name| say "    #{name}" }
        say ""

        inside(destination_root) { run "bin/rails db:migrate" }
      end

      def say_how_to_do_it_later
        say [
          "",
          "  Sin tocar la base de datos. Cuando quieras:",
          "",
          "    bin/rails db:migrate",
          "    bin/rails generate hobo:migration",
          "",
        ].join("\n"), :yellow
      end

      # Los nombres de las migraciones sin aplicar. En otro proceso, como todo lo
      # que pregunta por el estado de la base: la de dentro es la que había al
      # arrancar el generador.
      #
      # Si no se puede preguntar -- no hay base de datos todavía, que es lo
      # normal en una aplicación recién creada -- son los ficheros de
      # `db/migrate`, que es la misma respuesta por otro camino.
      def pending_migrations
        probe = File.join(destination_root, "tmp", "hobo_pending_probe.rb")
        FileUtils.mkdir_p(File.dirname(probe))
        File.write(probe, <<~RUBY)
          print ActiveRecord::Base.connection_pool.migration_context.open.pending_migrations.map(&:name).join(" ")
        RUBY

        said = `cd #{destination_root} && bin/rails runner #{probe} 2>/dev/null`.strip
        return said.split if $?.success?

        Dir[File.join(destination_root, "db", "migrate", "*.rb")]
          .map { |file| File.basename(file, ".rb").sub(/\A\d+_/, "").camelize }
      ensure
        FileUtils.rm_f(probe)
      end

      # Asked in another process, for the same reason the migration is written
      # in one: the models on disk are not the ones in memory.
      #
      # The lambda is not optional in practice -- the migrator calls it to ask
      # whether a column that went away was dropped or renamed, and its default,
      # an empty Hash, does not answer to `call`. This one is only looking, so
      # nothing is ever renamed.
      def anything_to_migrate?
        probe = File.join(destination_root, "tmp", "hobo_migration_probe.rb")
        FileUtils.mkdir_p(File.dirname(probe))
        File.write(probe, <<~RUBY)
          require "generators/hobo/migration/migrator"
          up, = ::Generators::Hobo::Migration::Migrator.new(lambda { |_c, _d, _k, _p| {} }).generate
          print up.to_s.strip.empty? ? "NADA" : "ALGO"
        RUBY

        said = `cd #{destination_root} && bin/rails runner #{probe} 2>&1`
        # If it could not be asked, ask the person: one question too many beats
        # a column that never gets created.
        !said.include?("NADA")
      ensure
        FileUtils.rm_f(probe)
      end

      def routes = @routes ||= File.read(File.join(destination_root, "config", "routes.rb"))

      # `application` appends inside the Application class, and running the
      # wizard twice must not say the same thing twice.
      def add_to_configuration(line)
        return say("  ya estaba: #{line}") if File.read(File.join(destination_root, "config", "application.rb")).include?(line)
        application "    #{line}"
      end

    end

  end
end
