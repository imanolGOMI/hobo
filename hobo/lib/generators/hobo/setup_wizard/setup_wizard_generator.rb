require "rails/generators"
require "generators/hobo/user_options"
require "hobo_rapid/translation"

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
                   :desc => "clean (por defecto), bootstrap, o none"
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
        @invite_only = yes_or_no?(:invite_only,
                                  "Solo se entra por invitacion? (un administrador invita; no hay alta publica)", false)
        @activation_email = @invite_only ? false : yes_or_no?(:activation_email, "El alta tiene que confirmarse por correo?", false)
        @admin = yes_or_no?(:admin, "Quieres un subsitio de administracion?", false)
        @admin_name = @admin ? named(:admin_name, "Como se llama el subsitio de administracion?", "admin") : "admin"
        @private = yes_or_no?(:private, "Todo el sitio detras del login? (si no, cada modelo decide quien ve sus paginas)", false)
        @locales, @locale = choose_locales
        @front = named(:front, "Como se llama el controlador de la portada?", "front")
        @migration = choose_migration
        @git = yes_or_no?(:git, "Dejo el trabajo en un commit de git?", false)

        # Not a question: Hobo 2 gave every application `/search` and the box in
        # the bar without asking, and taking it away turned out to be a change
        # nobody had asked for.
        @search = options[:search] != false
      end

      # --- what the answers mean -------------------------------------------------

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

        sheets = @theme == "bootstrap" ? %w[bootstrap hobo] : %w[clean]
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

      # Hobo 2 asked this and it was the right question: what the wizard has just
      # written -- a lifecycle, an administrator column -- is columns the
      # database does not have yet, and an application that starts without them
      # fails on its first page. Printing a reminder instead was leaving the job
      # half done.
      def the_migration
        case @migration
        when :skip
          say "\n  Sin tocar la base de datos. Cuando quieras:  bin/rails generate hobo:migration\n", :yellow
        when :generate
          say_step "La migracion"
          invoke "hobo:migration", [], :default_name => true, :generate => true
          say "\n  Escrita, sin aplicar. Para aplicarla:  bin/rails db:migrate\n", :green
        else
          say_step "La migracion"
          invoke "hobo:migration", [], :default_name => true, :migrate => true
        end
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

      def choose_theme
        given = options[:theme]
        return given if given.present?
        return "clean" unless interactive?

        said = ask("Tema: [c]lean (el de Hobo), [b]ootstrap, [n]inguno? [c]").to_s.strip.downcase
        { "b" => "bootstrap", "n" => "none" }.fetch(said[0].to_s, "clean")
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

      # Hobo 2's `[s]kip, [g]enerate, [m]igrate`, and the same three answers as
      # flags so a script never stops.
      def choose_migration
        return :skip if options[:skip_migration]
        return :generate if options[:generate_migration]
        return :migrate unless interactive?

        said = ask("La migracion inicial: [s]altarla, solo [e]scribirla, escribirla y [a]plicarla? [a]").to_s.strip.downcase
        { "s" => :skip, "e" => :generate }.fetch(said[0].to_s, :migrate)
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
