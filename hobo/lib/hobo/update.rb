# `hobo update` -- bringing an application written for Hobo 2 to this one.
#
# The promise Imanol asked for is "install the versions and change the Gemfile".
# That is the right shape, and this is what stands behind it: the parts of the
# jump that are mechanical are done here, and what is left is **named**, one
# item at a time, instead of turning up as a stack trace on a Tuesday.
#
#     cd my_old_app
#     hobo update              # says what it would do, changes nothing
#     hobo update --write      # does it
#
# ## Why it builds a new skeleton instead of patching the old one
#
# Between Rails 3.2 and 8.1 there are five major versions, and almost everything
# under `config/` and `bin/` was rewritten in that time -- the boot file, the
# environments, the initializers, the binstubs. Patching those by hand, rule by
# rule, is a pile of guesses that goes stale with every Rails release.
#
# So the skeleton is written by the thing whose job that is: `hobo new`, which
# is `rails new` with Hobo wired in, and which is already tested. What this does
# is carry the **application** across -- its models, its controllers, its views,
# its routes, its database, its locales -- and merge the two Gemfiles.
#
# The old application is not touched. What comes out is a new directory next to
# it, so the two can be run side by side and compared, which is the only way
# anybody trusts an upgrade.

require "fileutils"

module Hobo

  class Update

    # What belongs to the application and comes across as it is.
    #
    # `config/` is mostly not on the list, and that is the point: `config/
    # locales/` is the application's and comes over, and the rest of `config/`
    # belongs to whichever Rails this is. `config/routes.rb` is not here because
    # it is **merged**, not copied -- see write_routes.
    CARRIED = %w[
      app db lib public vendor/assets
      config/locales
      doc script/import spec test
    ].freeze

    # Initializers that were Rails 3's own plumbing and whose file is gone.
    # Everything else in `config/initializers/` is the application's -- its
    # constants, its api keys, the setup of a gem it uses -- and comes across.
    # Leaving the whole directory behind is what made the models raise for an
    # `uninitialized constant` that had been sitting there all along.
    DEAD_INITIALIZERS = %w[
      secret_token.rb session_store.rb wrap_parameters.rb
      backtrace_silencers.rb dryml_taglibs.rb
    ].freeze

    # Gems that were Hobo 2's own. They do not come across because their work is
    # inside the one gem now (decision 11) or because they are a theme, which is
    # a gem of its own with a new name.
    HOBO_2_GEMS = %w[
      hobo hobo_jquery hobo_jquery_ui hobo_bootstrap hobo_bootstrap_ui
      hobo_paperclip hobo-metasearch hobo_metasearch will_paginate
      hobo_will_paginate hobo_activerecord hobo_fields hobo_support
      hobo_rapid dryml
    ].freeze

    # Gems that are gone, with what to do instead. Carrying them across is what
    # makes `bundle install` fail before anything else can be looked at, and the
    # reason is worth more than the failure.
    RETIRED = {
      "rails" => "la version nueva la escribe `hobo new`",
      "sqlite3" => "ya viene",
      "puma" => "ya viene",
      "thin" => "el servidor es puma",
      "coffee-rails" => "CoffeeScript se retiro de Rails en la 6",
      "sass-rails" => "los assets son propshaft; el css se escribe css",
      "uglifier" => "no hay compilador de js que configurar",
      "jquery-rails" => "jQuery ya no viene de serie: gema hobo_jquery si la quieres",
      "jquery-ui-themes" => "gema hobo_jquery_ui",
      "turbolinks" => "el relevo es turbo, y ya viene",
      "bootstrap-sass" => "gema hobo_bootstrap",
      "will_paginate-bootstrap" => "la paginacion la pinta el tema",
      "protected_attributes" => "los permisos del modelo dicen que se puede asignar",
      "rails-dev-boost" => "la recarga de Rails 8 ya es rapida",
      "rails-console-tweaks" => "de Rails 3",
      "spork" => "sin relevo; las pruebas arrancan solas",
      "poltergeist" => "PhantomJS esta muerto: selenium",
      "capybara-screenshot" => "capybara ya las hace",
      "better_errors" => "la pagina de error de Rails 8 hace lo mismo",
      "binding_of_caller" => "iba con better_errors",
      "factory_girl_rails" => "se llama factory_bot_rails",
      "paperclip" => "sin mantener desde 2018: ActiveStorage",
      "exception_notification" => "la version fijada es de Rails 3",
      "yaml_db" => "de Rails 3",
      "whisk_deploy" => "el despliegue de Rails 8 es kamal",
      "rake" => "ya viene",
      "listen" => "ya viene",
    }.freeze

    def initialize(source, write: false, name: nil, theme: "clean", out: $stdout)
      @source = File.expand_path(source)
      @write = write
      # `--as` names the new one; without it, the old name with `_hobo3` behind,
      # which makes it clear which is which without looking inside.
      @name = name || "#{File.basename(@source)}_hobo3"
      @theme = theme
      @out = out
      @notes = []
    end

    attr_reader :source, :name, :notes

    def target = File.join(File.dirname(@source), @name)

    def run
      abort_with("#{@source} no existe") unless File.directory?(@source)
      abort_with("#{@source} no parece una aplicacion Rails") unless File.exist?(File.join(@source, "config", "application.rb"))

      say "Aplicacion:  #{@source}"
      say "Resultado:   #{target}"
      say ""

      look
      report
      return unless @write

      say ""
      say "Escribiendo…"
      build_skeleton
      carry
      write_routes
      write_model_fixes
      write_controller_fixes
      write_autoload_ignores
      write_callback_switch
      write_settings
      write_gemfile
      say ""
      say "Hecho. Ahora:"
      say "  cd #{target} && bundle install && bin/rails server"
    end

    # --- looking ---------------------------------------------------------------

    def look
      note :dryml, dryml_templates.length, "plantillas DRYML" do
        generated = dryml_templates.count { |file| file.include?("/taglibs/auto/") }
        [
          "#{generated} las genera Hobo 2 y se tiran: Hobo 3 deriva esas paginas sola.",
          "Las otras #{dryml_templates.length - generated} hay que convertirlas. Se copian tal cual y",
          "no estorban -- Rails las ignora --, pero sus paginas salen derivadas hasta que se conviertan.",
        ]
      end

      note :attr_accessible, attr_accessible_models.length, "modelos con attr_accessible" do
        ["Ya no hace nada. Lo que se puede asignar lo dicen create_permitted? y update_permitted?.",
         attr_accessible_models.first(6).join(", ")]
      end

      note :paperclip, paperclip_models.length, "modelos con paperclip" do
        ["Sin mantener desde 2018. El relevo es ActiveStorage y viene dentro de Rails.",
         paperclip_models.first(6).join(", ")]
      end

      note :plugins, vendor_plugins.length, "plugins en vendor/plugins" do
        ["Rails los dejo de cargar en la 4. Hay que meterlos en lib/ o en una gema.",
         vendor_plugins.join(", ")]
      end

      note :gems, retired_gems.length, "gemas que ya no existen" do
        retired_gems.map { |gem| "#{gem}: #{RETIRED[gem]}" }
      end
    end

    def report
      if @notes.empty?
        say "No hay nada que avisar."
      else
        @notes.each do |title, lines|
          say title
          lines.each { |line| say "        #{line}" }
          say ""
        end
      end

      say(@write ? "" : "Nada escrito. Repitelo con --write.")
    end

    # --- the facts, read from the files ---------------------------------------

    def dryml_templates
      @dryml_templates ||= Dir[File.join(@source, "app", "views", "**", "*.dryml")]
    end

    def models
      @models ||= Dir[File.join(@source, "app", "models", "*.rb")]
    end

    def attr_accessible_models
      @attr_accessible_models ||= models.select { |file| File.read(file).match?(/^\s*attr_accessible\b/) }
                                        .map { |file| File.basename(file, ".rb") }
    end

    def paperclip_models
      @paperclip_models ||= models.select { |file| File.read(file).match?(/has_attached_file/) }
                                  .map { |file| File.basename(file, ".rb") }
    end

    def vendor_plugins
      @vendor_plugins ||= Dir[File.join(@source, "vendor", "plugins", "*")].select { |p| File.directory?(p) }
                                                                          .map { |p| File.basename(p) }
    end

    # The gems the old Gemfile asks for, by name.
    def declared_gems
      @declared_gems ||= File.read(File.join(@source, "Gemfile")).scan(/^\s*gem\s+["']([^"']+)["']/).flatten
    rescue Errno::ENOENT
      []
    end

    def retired_gems = declared_gems & RETIRED.keys

    # What comes across: neither Hobo 2's own nor the retired ones.
    def kept_gems = declared_gems - HOBO_2_GEMS - RETIRED.keys

    # --- writing ---------------------------------------------------------------

    # The skeleton, built **from somewhere else**.
    #
    # `rails new` refuses to run inside the directory of another Rails
    # application, and `hobo new` inherits that. Which is exactly where this is
    # run from: you go into your application and say `hobo update`. Without the
    # `chdir` the command fails on its first step, in the one place everybody
    # will use it.
    def build_skeleton
      FileUtils.rm_rf(target)
      hobo = File.expand_path("../../bin/hobo", __dir__)

      Dir.chdir(File.dirname(target)) do
        system(hobo, "new", target, *skeleton_flags, :out => File::NULL) or
          abort_with("`hobo new` fallo")
      end
    end

    # What the new application is generated with. The theme is the one question
    # that shows on every page, so it is asked rather than assumed; the rest are
    # `hobo new`'s own defaults, and `hobo:setup_wizard` changes any of them
    # later in an application that already exists.
    def skeleton_flags
      ["--theme=#{@theme}", "--skip-migration"]
    end

    def carry
      CARRIED.each do |path|
        from = File.join(@source, path)
        next unless File.exist?(from)

        to = File.join(target, path)
        FileUtils.mkdir_p(File.dirname(to))
        FileUtils.rm_rf(to)
        FileUtils.cp_r(from, to)
        say "  #{path}"
      end

      carry_initializers
      carry_database
    end

    # Rails 8 keeps sqlite in `storage/`, Rails 3 kept it in `db/`. The file
    # comes across with `db/`, so without this the new application looks at an
    # empty `storage/development.sqlite3`, sees no `schema_migrations`, and
    # answers "you have 120 pending migrations" on every page -- for a database
    # that has been there the whole time, a directory away.
    def carry_database
      Dir[File.join(@source, "db", "*.sqlite3")].each do |file|
        to = File.join(target, "storage", File.basename(file))
        FileUtils.mkdir_p(File.dirname(to))
        FileUtils.cp(file, to)
        say "  storage/#{File.basename(file)} (estaba en db/)"
      end
    end

    def carry_initializers
      carried = Dir[File.join(@source, "config", "initializers", "*")].reject do |file|
        DEAD_INITIALIZERS.include?(File.basename(file))
      end
      return if carried.empty?

      FileUtils.cp_r(carried, File.join(target, "config", "initializers"))
      say "  config/initializers (#{carried.length})"
    end

    # Two things Rails stopped accepting, both of which stop the boot dead --
    # not a page, the boot -- and both of which are a rewrite with one right
    # answer. They are done in the models and left listed, so nobody finds out
    # months later that a line changed.
    #
    #   `:format => { :with => /^x$/ }`   In Ruby `^` and `$` are the ends of a
    #                                     **line**, so a value with a newline in
    #                                     it passed a validation meant to reject
    #                                     it. Rails made it an error and says
    #                                     what to write: `\A` and `\z`.
    #
    #   `:if => "estado == 'x'"`          A string that used to be `eval`ed.
    #                                     Rails 8 wants a symbol or a lambda,
    #                                     and the lambda is the same code.
    def write_model_fixes
      changed = Hash.new { |hash, key| hash[key] = [] }

      Dir[File.join(target, "app", "models", "*.rb")].each do |file|
        text = File.read(file)
        before = text.dup

        text.gsub!(/(:format\s*=>\s*\{[^}]*?:with\s*=>\s*\/)\^(.*?)\$(\/)/m) do
          changed[File.basename(file)] << "regex ^ $ -> \\A \\z"
          "#{$1}\\A#{$2}\\z#{$3}"
        end

        text.gsub!(/(:(?:if|unless)\s*=>\s*)"([^"]*)"/) do
          changed[File.basename(file)] << "#{$1.strip} con cadena -> lambda"
          "#{$1}-> { #{$2.gsub("'", '"')} }"
        end

        next if text == before
        File.write(file, text)
      end

      return if changed.empty?

      changed.each { |model, fixes| say "  app/models/#{model} (#{fixes.uniq.join("; ")})" }
    end

    # `before_filter` and its family were renamed to `_action` in Rails 5 and
    # removed in 5.1. A rename, nothing else, and it stops the boot on the first
    # controller that uses it.
    FILTERS = %w[before after around].flat_map do |when_|
      ["#{when_}_filter", "skip_#{when_}_filter"]
    end.freeze

    def write_controller_fixes
      changed = []

      Dir[File.join(target, "app", "controllers", "**", "*.rb")].each do |file|
        text = File.read(file)
        before = text.dup

        FILTERS.each { |filter| text.gsub!(/\b#{filter}\b/, filter.sub("_filter", "_action")) }

        next if text == before
        File.write(file, text)
        changed << file.sub("#{target}/", "")
      end

      return if changed.empty?
      say "  #{changed.length} controladores (before_filter -> before_action)"
    end

    # The routes, which are the application's and have to come across, written
    # the way Rails 8 reads them. Two things changed and both are mechanical:
    #
    #   `Amenti::Application.routes.draw` names the old application's module,
    #   and the new one is called something else. `Rails.application` is the
    #   name that does not depend on what the application is called.
    #
    #   `match 'x' => 'y#z'` needs a verb since Rails 4. `:via => :all` and not
    #   `get`, because that is what `match` meant: the old route answered POST
    #   too, and quietly turning it into a GET breaks a form months later.
    # Merged and not copied over. The old file has the application's own routes
    # and nothing else -- in Hobo 2 the routes of each model lived in a
    # *generated* `config/hobo_routes.rb` -- and the new one has `hobo_routes`,
    # which is where those come from now, plus the session and password routes
    # Rails 8 brings. Copying the old file on top loses all of it, and then
    # every url in the application answers 404, which is what it did.
    #
    # The old `root` wins: the front page belongs to the application.
    def write_routes
      routes = File.join(target, "config", "routes.rb")
      old = File.join(@source, "config", "routes.rb")
      return unless File.exist?(routes) && File.exist?(old)

      body = old_routes_body(File.read(old))
      return if body.strip.empty?

      text = File.read(routes)
      text.sub!(/^\s*root .*\n/, "") if body.match?(/^\s*root\b/)

      # A route name may only be used once, and both files name some of the
      # same things -- `site_search` is in `hobo new`'s and in this
      # application's. The application's wins, because it is the one that knows
      # where its search lives, and Rails refuses to load the file at all when
      # the two meet.
      route_names(body).each { |name| text.sub!(/^.*\bas:\s*:#{name}\b.*\n/, "") }

      text.sub!(/\nend\s*\z/, "\n\n#{ROUTES_HEADING}\n#{body}\nend\n")

      File.write(routes, text)
      say "  config/routes.rb (las rutas propias, sobre las de Hobo 3)"
    end

    ROUTES_HEADING = "  # --- de la aplicacion vieja --------------------------------------------".freeze

    # Every name the old file gives a route, written either way round.
    def route_names(body)
      body.scan(/:as\s*=>\s*['":]([\w]+)/).flatten + body.scan(/\bas:\s*:?["']?([\w]+)/).flatten
    end

    # The old file's body, written the way Rails 8 reads it.
    #
    # `match 'x' => 'y#z'` needs a verb since Rails 4, and `:via => :all` and not
    # `get`, because that is what `match` meant: the old route answered POST too,
    # and quietly turning it into a GET breaks a form months later. It goes
    # **before** a trailing `if`, which is a modifier and has to stay last.
    def old_routes_body(text)
      inner = text.sub(/\A.*?\.routes\.draw do\n/m, "").sub(/\nend\s*\z/, "")

      statements(inner).map do |statement|
        next statement unless statement.match?(/^\s*match\b/) && !statement.match?(/\bvia\b/)

        code, modifier = statement.rstrip.split(/\s+(?=(?:if|unless)\s)/, 2)
        "#{code}, :via => :all#{modifier ? " #{modifier}" : ""}\n"
      end.join
    end

    # Lines, except that a line ending in a comma is not finished. Route files
    # of that age wrap: `match 'x', :controller => :y,` and the rest underneath.
    # Rewriting line by line put `, :via => :all` after the trailing comma and
    # left `,,` in the file, so **no** route loaded and the whole application
    # answered 404.
    def statements(text)
      text.lines.slice_when { |line, _| !line.rstrip.end_with?(",") }.map(&:join)
    end

    # `lib/` in a Rails 3.2 application is a drawer: a csv, a vendored copy of
    # bootstrap-sass, some photos, a binary. Rails 8 autoloads `lib/` with
    # Zeitwerk, and Zeitwerk reads every directory name as a constant -- so
    # `lib/bootstrap-sass-4de54be4dd53` is not a naming quibble, it is an
    # application that does not boot.
    #
    # Nothing is moved or thrown away. What is written is the list of what not
    # to autoload, which is the line Rails 8 already has for exactly this.
    def write_autoload_ignores
      directories = Dir[File.join(target, "lib", "*")].select { |path| File.directory?(path) }
                                                      .map { |path| File.basename(path) }
      ignored = directories.reject { |name| name.match?(/\A[a-z_][a-z0-9_]*\z/) } | %w[assets tasks]
      return if ignored.sort == %w[assets tasks]

      application = File.join(target, "config", "application.rb")
      text = File.read(application)
      line = "config.autoload_lib(ignore: %w[#{ignored.sort.join(" ")}])"
      return unless text.sub!(/config\.autoload_lib\(ignore: %w\[[^\]]*\]\)/, line)

      File.write(application, text)
      say "  config/application.rb (autoload_lib: #{ignored.sort.join(", ")})"
    end

    # The `config.` lines the old application had said itself.
    #
    # `config/application.rb` is regenerated -- it has to be, five Rails
    # versions changed it -- and the application's own settings went with it.
    # The one that showed was `i18n.default_locale = :es`: the locale files were
    # carried, the application ran in English, and every `<t key="…">` in every
    # template came back empty. Not an error anywhere: an empty label.
    #
    # Only `config.` lines and only ones Rails 8 still has, one per line, so a
    # setting that no longer exists is left behind rather than carried into a
    # boot failure.
    KEPT_SETTINGS = %w[
      i18n.default_locale i18n.available_locales i18n.fallbacks
      time_zone active_record.default_timezone
      action_mailer.default_url_options action_mailer.delivery_method
      hobo.app_name
    ].freeze

    def write_settings
      old = File.read(File.join(@source, "config", "application.rb"))
      lines = KEPT_SETTINGS.filter_map do |setting|
        found = old[/^\s*(config\.#{Regexp.escape(setting)}\s*=.*)$/, 1]
        "    #{found}" if found
      end
      return if lines.empty?

      application = File.join(target, "config", "application.rb")
      text = File.read(application)
      block = "\n    # De la aplicacion vieja, dichas por ella.\n#{lines.join("\n")}\n"
      return unless text.sub!(/^(\s*config\.autoload_lib.*\n)/) { "#{$1}#{block}" }

      File.write(application, text)
      say "  config/application.rb (#{lines.length} ajustes de la vieja)"
    end

    # Since Rails 7.1 a filter that names an action the controller does not have
    # raises. In an application of this age the shared `ApplicationController`
    # says `:except => [:login, :signup, ...]`, and most controllers have none
    # of those -- so every page 404s with a message about a callback.
    #
    # Rails itself offers the switch for exactly this, and it is set here rather
    # than left to be found: what the old filters mean has not changed, only how
    # loudly Rails complains about the ones that do not apply.
    #
    # In `config/environments/`, which is where Rails writes it. Setting it in
    # `config/application.rb` looks right and does nothing: the environment
    # files are read afterwards and each one sets it back to `true`.
    def write_callback_switch
      changed = Dir[File.join(target, "config", "environments", "*.rb")].select do |file|
        text = File.read(file)
        next false unless text.sub!(/^(\s*config\.action_controller\.raise_on_missing_callback_actions\s*=\s*)true/) do
          "#{$1}false # al venir de Hobo 2: los filtros nombran acciones que no todos los controladores tienen"
        end

        File.write(file, text)
      end

      return if changed.empty?
      say "  config/environments (raise_on_missing_callback_actions => false)"
    end

    # The old Gemfile's gems, minus Hobo 2's own and minus the retired ones,
    # appended to the one `hobo new` wrote. Appended and not merged, so that what
    # came from the old application is visible in one block and can be gone
    # through by hand.
    def write_gemfile
      return if kept_gems.empty?

      lines = ["", "# --- de la aplicacion vieja ---------------------------------------------",
               "# Repasalas: estan aqui porque el Gemfile viejo las pedia, no porque se",
               "# haya comprobado que sigan vivas."]
      lines += kept_gems.map { |gem| %(gem "#{gem}") }

      File.open(File.join(target, "Gemfile"), "a") { |file| file.puts(lines.join("\n")) }
      say "  Gemfile (+#{kept_gems.length} gemas)"
    end

    # --- saying ----------------------------------------------------------------

    def note(key, count, what)
      return if count.zero?
      @notes << ["AVISO  #{count} #{what}", Array(yield)]
    end

    def say(line) = @out.puts(line)

    def abort_with(message)
      @out.puts(message)
      raise Hobo::Update::Error, message
    end

    class Error < StandardError; end

  end

end
