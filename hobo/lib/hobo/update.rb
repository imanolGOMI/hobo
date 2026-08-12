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

    # What comes across whole rather than merged: see `carry`.
    REPLACED = %w[db].freeze

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

    # Gems that are still alive but that **moved a piece out of themselves**.
    #
    # These are worse than a retired gem, because nothing complains: the gem
    # installs, `bundle install` is quiet, and what fails is a constant, on the
    # first request that reaches the code naming it. So they are looked for in
    # the source rather than in the Gemfile, and what is said is the exact line
    # to write instead.
    #
    # They are **named and not rewritten**, for the same reason as the Bootstrap
    # classes (decision 23): this is the application's own code calling somebody
    # else's gem, and there is no version of that this command should be editing
    # behind your back.
    MOVED = {
      "ActiveMerchant::Billing::Integrations" =>
        { :gem => "offsite_payments", :becomes => "OffsitePayments::Integrations",
          :and => "money",
          :since => "activemerchant 2.0 las saco a una gema aparte" },
      "ActiveMerchant::Billing::Integrations::ActionViewHelper" =>
        { :gem => "offsite_payments", :becomes => "OffsitePayments::ActionViewHelper",
          :and => "money",
          :since => "activemerchant 2.0 las saco a una gema aparte" },
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
      write_authentication
      write_autoload_ignores
      write_callback_switch
      write_settings
      write_theme_classes
      write_bootstrap_classes
      write_stylesheets
      write_attachments
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
        ["Sin mantener desde 2018. La declaracion se traduce a has_one_attached;",
         "**los ficheros no**. Paperclip los dejaba donde dijera su :path y cuatro",
         "columnas al lado del registro; ActiveStorage guarda un blob en sus tablas.",
         "Moverlos es lo unico que nadie puede hacer a ciegas: estan en un disco o en",
         "un bucket, y solo la aplicacion sabe cual.",
         "Las columnas que quedan sin uso: #{paperclip_columns.first(8).join(", ")}",
         paperclip_models.first(6).join(", ")]
      end

      note :plugins, vendor_plugins.length, "plugins en vendor/plugins" do
        ["Rails los dejo de cargar en la 4. Hay que meterlos en lib/ o en una gema.",
         vendor_plugins.join(", ")]
      end

      note :bootstrap, bootstrap_classes.length, "clases de Bootstrap viejo que hay que mirar a mano" do
        ["Las de la rejilla, los flotados y el carrusel se cambian solas -- tienen una",
         "traduccion exacta. Estas no la tienen y se quedan como estan:"] +
          bootstrap_classes.map { |name| "  #{name} -> #{RENAMED_IN_BOOTSTRAP[name]}" }
      end

      note :sass, (sass_gems - retired_gems).length, "gemas de Sass que no compilaran" do
        ["Rails 8 usa Propshaft, que **sirve** ficheros y no los procesa: no hay Sass.",
         "Se llevan al Gemfile porque son tuyas, pero su css no se generara.",
         "O anades dartsass-rails, o pones el css ya compilado en app/assets.",
         (sass_gems - retired_gems).join(", ")]
      end

      note :gems, retired_gems.length, "gemas que ya no existen" do
        retired_gems.map { |gem| "#{gem}: #{why_retired(gem)}" }
      end

      note :passwords, (old_password_columns.empty? ? 0 : 1), "tabla de usuarios con las claves de Hobo 2" do
        ["Hobo 2 guardaba `#{old_password_columns.join(", ")}`. La autenticacion de Rails 8",
         "guarda `password_digest`, que es bcrypt: **son algoritmos distintos y no se",
         "convierten** -- un hash no se puede volver a la clave que lo genero.",
         "",
         "La aplicacion arranca y las paginas se ven, pero **nadie puede entrar**.",
         "Lo que hay que hacer, y solo lo puedes decidir tu:",
         "  1. una migracion que anada `password_digest` a users y cree la tabla",
         "     `sessions` (id, user_id, ip_address, user_agent), que es donde Rails 8",
         "     guarda la sesion. Las migraciones del esqueleto no se traen: son para",
         "     una base vacia y la tuya ya existe.",
         "  2. `has_secure_password` en el modelo, y",
         "  3. que cada usuario pase una vez por «he olvidado mi clave».",
         "O quedarte con el comprobador viejo si prefieres no tocar las claves."]
      end

      note :moved, moved_constants.length, "constantes que se mudaron de gema" do
        ["Su gema sigue viva, pero esto ya no esta dentro. `bundle install` no dira",
         "nada: falla la constante, en la primera peticion que llegue ahi.",
         "Anade la gema al Gemfile y cambia el nombre:"] +
          moved_constants.flat_map do |written, files|
            moved = MOVED[written]
            # `offsite_payments` is the case: it installs, and then refuses to
            # load until you have chosen an implementation of Money. A gem that
            # a second gem needs at boot is part of the answer, not a detail.
            gems = [moved[:gem], *moved[:and]].map { |name| %(gem "#{name}") }.join(", ")

            ["  #{written}",
             "    -> #{moved[:becomes]}   (#{gems} -- #{moved[:since]})",
             "    en #{files.map { |file| relative(file) }.join(", ")}"]
          end
      end

      note :examples, orphan_examples.length, "ficheros de ejemplo sin su pareja" do
        ["La aplicacion trae un `.example` y no el fichero de verdad, casi siempre",
         "porque el de verdad esta en .gitignore: lleva claves.",
         "**Si actualizas tu aplicacion, lo normal es que ya lo tengas** y se lleva",
         "solo: esto sale cuando se actualiza una copia recien clonada, donde no esta.",
         "El ejemplo se copia tal cual y no se renombra -- un fichero de claves con",
         "las de mentira dentro arranca y luego hace lo que no es. Trae el bueno de",
         "donde corra la aplicacion, o copialo y rellenalo:"] +
          orphan_examples.map { |file| "  #{relative(file)} -> #{relative(file).sub(/\.(example|sample)\z/, "")}" }
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

    # The columns paperclip left beside each record, which nothing reads now.
    def paperclip_columns
      models.flat_map do |file|
        File.read(file).scan(/has_attached_file\s+:(\w+)/).flatten.flat_map do |name|
          %w[file_name content_type file_size updated_at].map { |suffix| "#{name}_#{suffix}" }
        end
      end.uniq
    end

    # The password columns Hobo 2 wrote, read from the schema. `password_digest`
    # beside them means somebody has already done the move, so there is nothing
    # to say.
    OLD_PASSWORD_COLUMNS = %w[crypted_password salt password_salt].freeze

    def old_password_columns
      @old_password_columns ||= begin
        schema = File.join(@source, "db", "schema.rb")
        text = File.exist?(schema) ? File.read(schema) : ""
        text.include?("password_digest") ? [] : OLD_PASSWORD_COLUMNS.select { |name| text.include?(%("#{name}")) }
      end
    end

    def vendor_plugins
      @vendor_plugins ||= Dir[File.join(@source, "vendor", "plugins", "*")].select { |p| File.directory?(p) }
                                                                          .map { |p| File.basename(p) }
    end

    # Which of the moved constants this application writes, and where.
    #
    # Longest first, because one of them is inside another:
    # `…Integrations::ActionViewHelper` also matches `…Integrations`, and the
    # line to write is not the same one.
    def moved_constants
      @moved_constants ||= begin
        found = Hash.new { |hash, key| hash[key] = [] }
        names = MOVED.keys.sort_by { |name| -name.length }

        Dir[File.join(@source, "{app,lib,config}", "**", "*.{rb,dryml,erb}")].each do |file|
          text = File.read(file)
          names.each do |name|
            next unless text.include?(name)
            found[name] << file
            text = text.gsub(name, "")
          end
        end

        found
      end
    end

    # `config/database.yml.example` with no `config/database.yml` beside it.
    #
    # The real one is in `.gitignore` -- it carries keys -- so a checkout has the
    # example and nothing else, and the application boots until the first line
    # that reads a constant that was supposed to be in there.
    def orphan_examples
      @orphan_examples ||= Dir[File.join(@source, "config", "**", "*.{example,sample}")]
                           .reject { |file| File.exist?(file.sub(/\.(example|sample)\z/, "")) }
    end

    def relative(file) = file.sub("#{@source}/", "")

    # The gems the old Gemfile asks for, by name.
    def declared_gems
      @declared_gems ||= File.read(File.join(@source, "Gemfile")).scan(/^\s*gem\s+["']([^"']+)["']/).flatten
    rescue Errno::ENOENT
      []
    end

    # `bootstrap-sass` is retired **only when it was Hobo's**.
    #
    # In an application on the bootstrap theme it came in with
    # `hobo_bootstrap`, and the theme brings its own Bootstrap now. In one on
    # `clean` the application added it itself, for its own markup, and dropping
    # it takes away a design nobody asked us to touch.
    BOOTSTRAP_SASS = "venia con hobo_bootstrap; el tema trae su Bootstrap ya compilado"

    def retired_gems
      retired = declared_gems & RETIRED.keys
      retired += ["bootstrap-sass"] if declared_gems.include?("bootstrap-sass") && used_hobo_bootstrap?
      retired
    end

    # Why each one is gone. `bootstrap-sass` is not in the table because it is
    # only retired when it was Hobo's -- and printing its name with nothing
    # behind the colon was the whole reason anybody would ask.
    def why_retired(gem) = RETIRED[gem] || BOOTSTRAP_SASS

    def used_hobo_bootstrap? = declared_gems.include?("hobo_bootstrap")

    # And the ones that come across and **will not build**. Rails 8 compiles no
    # Sass: Propshaft serves files, it does not process them. Saying it here is
    # the difference between an afternoon and a stylesheet that is simply not
    # there.
    SASS_GEMS = %w[bootstrap-sass sass-rails compass-rails bourbon neat].freeze

    def sass_gems = declared_gems & SASS_GEMS

    # Which of the renamed-in-Bootstrap classes this application actually
    # writes. Listing the ones it does not use would be noise.
    def bootstrap_classes
      @bootstrap_classes ||= begin
        written = Dir[File.join(@source, "app", "views", "**", "*.{dryml,erb}")].flat_map do |file|
          File.read(file).scan(/class=["\']([^"\']*)["\']/).flatten.flat_map(&:split)
        end.uniq
        # Menos las que se cambian solas: nombrar algo que el comando ya ha
        # hecho es ruido, y el informe deja de decir la verdad en cuanto una
        # cosa esta en las dos listas.
        (RENAMED_IN_BOOTSTRAP.keys & written) - REWRITTEN_IN_BOOTSTRAP.keys
      end
    end

    # What comes across: neither Hobo 2's own, nor the retired ones, nor the ones
    # the new Gemfile already asks for.
    #
    # `retired_gems` and not `RETIRED.keys`: `bootstrap-sass` is retired only
    # when it was Hobo's, so the table does not have it and the subtraction left
    # it in -- the report said the gem was gone and the Gemfile installed it two
    # lines later.
    #
    # And Rails 8 writes its own `capybara`, `debug` and `brakeman`. Naming one
    # twice is only a warning from bundler, but it is a warning on every single
    # command the application runs from then on.
    def kept_gems = declared_gems - HOBO_2_GEMS - retired_gems - skeleton_gems

    # The gems `hobo new` already put in the Gemfile, read from the file it
    # wrote rather than from a list here, which would go stale with Rails.
    def skeleton_gems
      @skeleton_gems ||= File.read(File.join(target, "Gemfile"))
                             .scan(/^\s*gem\s+["']([^"']+)["']/).flatten
    rescue Errno::ENOENT
      []
    end

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
        # `db/` es de la aplicacion **entero**: su esquema y sus migraciones son
        # la historia de su base de datos, y las que trae el esqueleto estan
        # escritas para una aplicacion nueva. Dejarlas al lado no anade nada:
        # quedan pendientes contra una base que ya existe y Rails contesta
        # `ActiveRecord::PendingMigrationError` en todas las paginas.
        FileUtils.rm_rf(to) if REPLACED.include?(path)
        merge_over(from, to)
        say "  #{path}"
      end

      carry_initializers
      carry_database
    end

    # The old application's files **on top of** the skeleton's, without taking
    # away what the skeleton put there.
    #
    # It used to be `rm_rf` and then copy, and `app` is on the list -- so the
    # whole generated `app/` went in the bin, and with it Rails' own
    # authentication: `SessionsController`, `PasswordsController`, `Session`,
    # `Current`. `hobo new` had written them two steps earlier.
    #
    # What that looked like: every page painted, and `/session/new` answered 500
    # with `uninitialized constant SessionsController`. **You could not log in to
    # the application you had just brought across**, and nothing in the update
    # said a word about it.
    #
    # A file the old application has still wins -- it is its application -- and
    # one it does not have simply stays.
    def merge_over(from, to)
      unless File.directory?(from)
        FileUtils.cp(from, to)
        return
      end

      FileUtils.mkdir_p(to)
      Dir.children(from).each { |child| merge_over(File.join(from, child), File.join(to, child)) }
    end

    # The application's own stylesheets, **flattened**.
    #
    # In Rails 3 a stylesheet was a Sprockets manifest: a comment block full of
    # `*= require` that pulled other files in and concatenated them. Rails 8 uses
    # Propshaft, which **serves files and does not process them**, so every one
    # of those directives is a dead comment.
    #
    # What that costs: amenti's `front.css` requires `application` and then
    # `require_tree ./front`, and inside `front/` is `saturno.css` -- 6 KB, the
    # whole design of the site. Nothing linked it, Propshaft would not even serve
    # it by that name, and the page came out with Hobo's own styling and none of
    # the application's. It looked like "the theme is wrong" rather than "your
    # stylesheet is not there", which is why it took a screenshot to see.
    #
    # So the directives are resolved here, once, and what is written is a real
    # css file with the content in it -- exactly what Sprockets used to hand the
    # browser. What is **not** resolved is a `require` naming a gem: Hobo 3
    # brings its own theme, and a stylesheet from a gem that no longer exists is
    # not ours to invent.
    def write_stylesheets
      return if stylesheet_manifests.empty?

      # `front` el ultimo: acaba en el mismo `application.css` que el manifiesto
      # de ese nombre, y es el que lo incluye -- al reves se perderia la mitad.
      ordered = stylesheet_manifests.sort_by { |file| File.basename(file).start_with?("front") ? 1 : 0 }

      written = ordered.filter_map do |file|
        name = File.basename(file).sub(/\.(css|scss|sass)\z/, "")
        body = resolve_manifest(file)
        next if body.strip.empty?

        # `front` is the name Hobo 2 gave the main subsite, and in Hobo 3 the
        # main site has **no** subsite -- so the page asks for `application`.
        # Writing it under the old name would leave it linked by nobody.
        target_name = name == "front" ? "application" : name
        File.write(File.join(target, "app", "assets", "stylesheets", "#{target_name}.css"), body)
        "#{target_name}.css"
      end

      # The manifests that are now dead weight: their content is in the flat
      # file, and leaving the `.scss` beside it means two stylesheets with the
      # same name and Propshaft picking one.
      stylesheet_manifests.each do |file|
        twin = File.join(target, "app", "assets", "stylesheets", File.basename(file))
        FileUtils.rm_f(twin) if File.extname(twin) != ".css"
      end

      return if written.empty?
      say "  app/assets/stylesheets (#{written.uniq.join(", ")}: directivas de Sprockets resueltas)"
    end

    def stylesheet_manifests
      @stylesheet_manifests ||= Dir[File.join(@source, "app", "assets", "stylesheets", "*.{css,scss,sass}")]
                                .select { |file| File.read(file).match?(SPROCKETS_DIRECTIVE) }
    end

    SPROCKETS_DIRECTIVE = /^\s*[*#\/]*=\s*(require_self|require_tree|require_directory|require)\s*(\S*)/

    # A manifest, turned into the css it stood for. In order, because in css the
    # last rule wins and Sprockets kept the order of the directives.
    def resolve_manifest(file, seen = [])
      return "" if seen.include?(file)
      seen << file

      text = File.read(file)
      pieces = text.scan(SPROCKETS_DIRECTIVE).map do |directive, argument|
        case directive
        when "require_self" then body_of(text)
        when "require_tree" then tree_of(file, argument, "**/*")
        when "require_directory" then tree_of(file, argument, "*")
        when "require" then resolve_required(file, argument, seen)
        end
      end

      # A manifest with no `require_self` still has its own rules -- Sprockets
      # put them at the end when nobody said where.
      pieces << body_of(text) unless text.match?(/=\s*require_self/)
      pieces.compact.reject(&:empty?).join("\n\n")
    end

    def tree_of(manifest, argument, glob)
      directory = File.expand_path(argument.to_s.sub(/\A\.\//, ""), File.dirname(manifest))
      Dir[File.join(directory, glob)].select { |f| f.match?(/\.(css|scss|sass)\z/) }.sort
          .map { |f| "/* #{File.basename(f)} */\n#{File.read(f)}" }.join("\n\n")
    end

    def resolve_required(manifest, name, seen)
      candidates = %w[css scss sass].map { |extension| File.expand_path("#{name}.#{extension}", File.dirname(manifest)) }
      found = candidates.find { |candidate| File.exist?(candidate) }
      # No file by that name in the application: it is a gem's, and Hobo 3 either
      # brings its own or the application has to. Named in the report, not
      # guessed at here.
      return "" unless found

      resolve_manifest(found, seen)
    end

    # A manifest file minus its directive block, which is a comment and would go
    # into the flat file as noise.
    def body_of(text)
      text.sub(%r{\A\s*/\*.*?\*/}m) { |block| block.match?(SPROCKETS_DIRECTIVE) ? "" : block }
          .gsub(SPROCKETS_DIRECTIVE, "")
          .strip
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

    # Rails' authentication, wired into the `ApplicationController` that came
    # across.
    #
    # `hobo new` writes `include Authentication` into the one it generates, and
    # every controller of Rails' own -- `SessionsController`,
    # `PasswordsController` -- is written against it: they open with
    # `allow_unauthenticated_access`, which is a class method that concern
    # brings. The old application has an `ApplicationController` of its own and
    # it wins, so those two lost the method and **the application would not
    # boot**: `undefined local variable or method
    # 'allow_unauthenticated_access'`.
    #
    # And `allow_unauthenticated_access` right behind it, at the top of the
    # tree. The concern hangs a `require_authentication` on **every** controller,
    # and an application coming from Hobo 2 already decides who has to log in --
    # amenti has a `before_action` naming its fifteen public actions. Adding a
    # second gate on top would put the whole public site behind a login nobody
    # asked for. So the mechanism is here and available, and who is required to
    # log in stays exactly where the application had it.
    def write_authentication
      concern = File.join(target, "app", "controllers", "concerns", "authentication.rb")
      file = File.join(target, "app", "controllers", "application_controller.rb")
      return unless File.exist?(concern) && File.exist?(file)

      write_repeatable_opt_out(concern)

      text = File.read(file)
      return if text.match?(/^\s*include Authentication\b/)

      opened = text.sub!(/^(class ApplicationController[^\n]*\n)/) do
        "#{$1}" \
          "  # La autenticacion de Rails 8, que es de la que dependen sus propios\n" \
          "  # controladores de sesion y de claves. Quien tiene que identificarse lo\n" \
          "  # sigue decidiendo esta aplicacion, como ya lo hacia.\n" \
          "  include Authentication\n" \
          "  allow_unauthenticated_access\n\n" \
          "  # Una pagina de Hobo es el documento entero, asi que el layout de\n" \
          "  # Rails la envolveria en un segundo <html>. Lo decide la plantilla:\n" \
          "  # una `.dryml` trae su documento y una `.html.erb` sigue con layout.\n" \
          "  include Hobo::Controller::Layout\n\n"
      end
      return unless opened

      File.write(file, text)
      say "  app/controllers/application_controller.rb (include Authentication)"
    end

    # `allow_unauthenticated_access`, dos veces, sin reventar.
    #
    # Rails lo escribe como un `skip_before_action` a secas, y eso es un error si
    # el filtro ya no esta -- que es justo lo que pasa en cuanto alguien se libra
    # en dos niveles: `ApplicationController` y despues cada controlador de
    # modelo, que se libra solo porque Hobo lo hace por ti. La aplicacion no
    # arrancaba: "Before process_action callback :require_authentication has not
    # been defined", en el primer controlador que cargaba Zeitwerk.
    #
    # `raise: false` es lo que esa linea queria decir: quitalo si esta.
    def write_repeatable_opt_out(concern)
      text = File.read(concern)
      return unless text.sub!(/skip_before_action :require_authentication, \*\*options/,
                              "skip_before_action :require_authentication, **{ :raise => false }.merge(options)")

      File.write(concern, text)
      say "  app/controllers/concerns/authentication.rb (librarse dos veces no revienta)"
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

    # Paperclip becomes ActiveStorage, as far as anybody can do it for you.
    #
    #   has_attached_file :logo, :styles => {…}   ->  has_one_attached :logo
    #
    # What is written is the declaration; what is **not** written is the data.
    # Paperclip kept the file wherever `:path` said and four columns beside the
    # record; ActiveStorage keeps a blob in its own tables. Moving the files is
    # the one part nobody can do blind: they are on a disk, or in a bucket, and
    # only the application knows which. So it is said, with the columns named,
    # and left alone.
    #
    # The `:styles` go too, and that is worth saying out loud: they were image
    # variants, and ActiveStorage has `variant` -- but a variant is asked for
    # where the image is painted, not where it is declared, so translating them
    # here would put them in the wrong place.
    def write_attachments
      changed = []

      Dir[File.join(target, "app", "models", "*.rb")].each do |file|
        text = File.read(file)
        before = text.dup

        # The declaration and everything hanging off it: paperclip's options run
        # over as many lines as they like, and they end where the indentation
        # goes back to a statement.
        text.gsub!(/^(\s*)has_attached_file\s+:(\w+).*?(?=\n\s*(?:[a-z_]+\s|end\b|\z))/m) do
          "#{$1}has_one_attached :#{$2}"
        end
        text.gsub!(/^\s*validates_attachment\w*.*?(?=\n\s*(?:[a-z_]+\s|end\b|\z))/m, "")

        next if text == before
        File.write(file, text)
        changed << File.basename(file, ".rb")
      end

      return if changed.empty?
      say "  #{changed.length} modelos (has_attached_file -> has_one_attached): #{changed.join(", ")}"
    end

    # The classes Hobo 2's theme wrote, and the **role** Hobo 3 writes instead.
    #
    # This is the map Hobo can own, and only this one. In Hobo 3 a tag emits a
    # role -- `action`, `card`, `aside-box` -- and the theme turns it into
    # whatever that theme calls it, so a template that says the role is dressed
    # by whichever theme is installed. A template that says `btn` is asking for
    # Bootstrap, and gets Bootstrap 5 whether it wanted it or not.
    #
    # `span4` is **not** here, and that is decision 23: it maps to `col-md-4`,
    # which is Bootstrap 2 to Bootstrap 5 -- somebody else's map, thousands of
    # classes, and not ours to keep up to date. Those are listed instead.
    THEME_CLASSES = {
      "btn" => "action",
      "btn-primary" => "new",
      "btn-danger" => "delete",
      "btn-mini" => "small",
      "btn-small" => "small",
      "well" => "aside-box",
      "row-fluid" => "row",
    }.freeze

    # The ones that are Bootstrap and have a straight rename in 5. Said, not
    # done: they are the application's markup and its call.
    RENAMED_IN_BOOTSTRAP = {
      "span1" => "col-md-1", "span2" => "col-md-2", "span3" => "col-md-3",
      "span4" => "col-md-4", "span5" => "col-md-5", "span6" => "col-md-6",
      "span7" => "col-md-7", "span8" => "col-md-8", "span9" => "col-md-9",
      "span10" => "col-md-10", "span11" => "col-md-11", "span12" => "col-md-12",
      "pull-right" => "float-end", "pull-left" => "float-start",
      "control-group" => "mb-3", "controls" => "(ya no hace falta)",
      "form-horizontal" => "row (en cada campo)",
      "input-block-level" => "form-control",
      "hero-unit" => "p-5 bg-body-tertiary rounded",
      "thumbnail" => "card",
      "icon-trash" => "un svg o bootstrap-icons",
      # `hidden` es el caso que mas engana: en Bootstrap 2 esconde y en el 5 no
      # existe, asi que lo que estaba escondido **aparece**. La portada de amenti
      # tiene un `<h1 class="hidden">Amenti</h1>` que salio a la vista.
      "hidden" => "d-none", "visible-phone" => "d-md-none", "hidden-phone" => "d-none d-md-block",
      "nav-collapse" => "collapse navbar-collapse", "btn-navbar" => "navbar-toggler",
      # El carrusel cambio de nombres y de atributos: `data-slide` es
      # `data-bs-slide`, y sin eso las flechas no hacen nada.
      "carousel-control" => "carousel-control-prev / carousel-control-next (y data-slide -> data-bs-slide)",
      "item" => "carousel-item (dentro de un carrusel)",
    }.freeze

    def write_theme_classes
      changed = 0

      Dir[File.join(target, "app", "views", "**", "*.{dryml,erb}")].each do |file|
        text = File.read(file)
        before = text.dup

        text.gsub!(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          %(class=#{quote}#{names.split.map { |n| THEME_CLASSES[n] || n }.join(" ")}#{quote})
        end

        next if text == before
        File.write(file, text)
        changed += 1
      end

      return if changed.zero?
      say "  #{changed} plantillas (clases del tema -> papeles de Hobo 3)"
    end

    # Bootstrap 2 -> Bootstrap 5, **escrito y no solo dicho**.
    #
    # Esto era una lista en el informe y ya no lo es. La razon de listarlas era
    # buena -- es marcado de la aplicacion llamando a Bootstrap, no a Hobo -- y
    # se cayo al mirar la pagina: `span5` y `span7` son las dos columnas de la
    # portada, y sin ellas todo queda en una sola tira. `hidden` es peor: en
    # Bootstrap 5 no existe, asi que **lo que estaba escondido aparece**, y la
    # portada de amenti salio con un titulo duplicado que llevaba trece anos
    # oculto. Una pagina que no se puede usar no es "el diseno del usuario".
    #
    # Se cambia solo lo que tiene una traduccion exacta y comprobable: la
    # rejilla, los flotados, el carrusel y sus atributos. Lo que no la tiene --
    # los iconos, que en Bootstrap 5 son otra gema o un svg -- se sigue
    # nombrando y no se toca. Y la aplicacion vieja no se toca nunca: esto se
    # escribe en la copia nueva, al lado.
    REWRITTEN_IN_BOOTSTRAP = {
      "row-fluid" => "row",
      "pull-right" => "float-end", "pull-left" => "float-start",
      "hidden" => "d-none",
      "input-block-level" => "form-control",
      "hero-unit" => "p-5 bg-body-tertiary rounded",
      "thumbnail" => "card",
      "nav-collapse" => "collapse navbar-collapse",
      "btn-navbar" => "navbar-toggler",
      "control-group" => "mb-3",
    }.merge((1..12).to_h { |n| ["span#{n}", "col-md-#{n}"] }).freeze

    # Los atributos que mueven los componentes. Bootstrap 5 los lee con `bs`
    # delante, y sin eso el javascript no se entera de que existen: el carrusel
    # se queda quieto con todas las fotos una encima de otra.
    BOOTSTRAP_DATA = %w[toggle target slide slide-to dismiss parent ride spy].freeze

    def write_bootstrap_classes
      changed = 0

      Dir[File.join(target, "app", "views", "**", "*.{dryml,erb}")].each do |file|
        text = File.read(file)
        before = text.dup

        text.gsub!(/class=(["'])([^"']*)\1/) do
          quote, names = Regexp.last_match(1), Regexp.last_match(2)
          %(class=#{quote}#{names.split.flat_map { |n| (REWRITTEN_IN_BOOTSTRAP[n] || n).split }.uniq.join(" ")}#{quote})
        end

        BOOTSTRAP_DATA.each { |name| text.gsub!(/\bdata-#{name}=/, "data-bs-#{name}=") }
        rewrite_carousel(text)

        next if text == before
        File.write(file, text)
        changed += 1
      end

      return if changed.zero?
      say "  #{changed} plantillas (clases de Bootstrap 2 -> Bootstrap 5)"
    end

    # El carrusel, que necesita saber donde esta.
    #
    # `item` es un nombre demasiado corriente para cambiarlo en cualquier sitio,
    # y dentro de un carrusel **tiene que** ser `carousel-item` o las fotos se
    # apilan. Asi que solo se toca en una plantilla que tiene un carrusel, y las
    # flechas, que en Bootstrap 2 se decian con `left` y `right` y ahora tienen
    # nombre propio.
    def rewrite_carousel(text)
      return text unless text.include?("carousel-inner")

      text.gsub!(/class=(["'])([^"']*\bitem\b[^"']*)\1/) do
        quote, names = Regexp.last_match(1), Regexp.last_match(2)
        %(class=#{quote}#{names.split.map { |n| n == "item" ? "carousel-item" : n }.join(" ")}#{quote})
      end
      text.gsub!(/carousel-control left/, "carousel-control-prev")
      text.gsub!(/carousel-control right/, "carousel-control-next")

      # Y la foto, que se sale. Bootstrap 2 le ponia `max-width: 100%` a toda
      # imagen; Bootstrap 3 quito esa regla global y desde entonces se pide con
      # clases. Sin ellas la foto sale a tamano natural y rompe la columna, que
      # es como se veia el carrusel de amenti: una imagen enorme desbordando.
      text.gsub!(/(class="[^"]*carousel-item[^"]*"[^>]*>\s*<img)((?![^>]*\bclass=)[^>]*?)(\s*\/?>)/m) do
        "#{Regexp.last_match(1)}#{Regexp.last_match(2)} class=\"d-block w-100\"#{Regexp.last_match(3)}"
      end
      text
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
    #
    # And `hobo_dryml` in front of them when the application has templates in
    # DRYML, which is the one gem this command can decide on its own: it has just
    # counted the `.dryml` files, and without the gem every one of those pages
    # comes out derived. Leaving it to a line in a report meant the first run
    # after an update always looked worse than it was.
    def write_gemfile
      lines = []

      unless dryml_templates.empty?
        lines += ["", "# El lenguaje DRYML, porque esta aplicacion trae #{dryml_templates.length} plantillas escritas en el.",
                  "# Quitala cuando las hayas convertido a .html.erb.", gem_line("hobo_dryml")]
      end

      unless kept_gems.empty?
        lines += ["", "# --- de la aplicacion vieja ---------------------------------------------",
                  "# Repasalas: estan aqui porque el Gemfile viejo las pedia, no porque se",
                  "# haya comprobado que sigan vivas."]
        lines += kept_gems.map { |gem| %(gem "#{gem}") }
      end

      return if lines.empty?

      File.open(File.join(target, "Gemfile"), "a") { |file| file.puts(lines.join("\n")) }
      say "  Gemfile (+#{kept_gems.length} gemas#{", +hobo_dryml" unless dryml_templates.empty?})"
    end

    # A gem line, pointing at the working tree when HOBODEV says to -- the same
    # rule `hobo new` follows, so that the two halves of a development checkout
    # do not disagree about where a gem is.
    def gem_line(name)
      development = ENV["HOBODEV"]
      path = development && [File.join(development, name, name), File.join(development, name)]
                            .find { |candidate| File.exist?(File.join(candidate, "#{name}.gemspec")) }
      path ? %(gem "#{name}", path: "#{path}") : %(gem "#{name}")
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
