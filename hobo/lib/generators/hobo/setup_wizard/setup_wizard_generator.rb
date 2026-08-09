require "rails/generators"
require "generators/hobo/user_options"

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
                   :desc => "Una caja de busqueda en la barra, que busca en todo el sitio"

      class_option :private, :type => :boolean,
                   :desc => "Todo el sitio detras del login"
      class_option :locale, :type => :string,
                   :desc => "El idioma de la aplicacion"
      class_option :front, :type => :string,
                   :desc => "Como se llama el controlador de la portada"
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
        @search = yes_or_no?(:search, "Quieres una caja de busqueda en la barra?", false)
        @private = yes_or_no?(:private, "Todo el sitio detras del login? (si no, cada modelo decide quien ve sus paginas)", false)
        @locale = named(:locale, "Idioma de la aplicacion?", "en")
        @front = named(:front, "Como se llama el controlador de la portada?", "front")
      end

      # --- what the answers mean -------------------------------------------------

      def write_the_configuration
        say_step "La configuracion"
        add_to_configuration "config.hobo.theme = #{@theme == "none" ? "false" : ":#{@theme}"}"
        add_to_configuration "config.hobo.private_site = true" if @private
        add_to_configuration "config.i18n.default_locale = :#{@locale}" unless @locale == "en"
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

      def a_place_for_your_own_words
        create_file "config/locales/app.#{@locale}.yml", <<~YAML unless File.exist?(File.join(destination_root, "config/locales/app.#{@locale}.yml"))
          # The names your application uses for its own things. Rails looks here for
          # them, and Hobo's pages ask Rails -- so a model called `Story` becomes
          # "Relato" everywhere by saying it once, here.
          #
          # Hobo's own strings are in the gem; to change one, write the same key in
          # a file of yours (config/locales/hobo.#{@locale}.yml).
          #{@locale}:
          #  activerecord:
          #    models:
          #      story:
          #        one: Story
          #        other: Stories
        YAML
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

      def the_migration
        say [
          "",
          "Listo. Si algun modelo ha cambiado, la migracion:",
          "",
          "  bin/rails generate hobo:migration",
          "",
        ].join("\n"), :green
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
