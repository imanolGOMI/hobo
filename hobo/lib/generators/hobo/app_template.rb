# The Rails application template behind `hobo new`.
#
#   hobo new blog
#
# It is a plain `rails new` with the gems wired in and one worked example, and
# that is the point: what comes out is a **Rails application**, not a thing that
# happens to be built on Rails. Everything is where a Rails developer looks.
#
# What it no longer does: the old `hobo new` ran an interactive wizard that
# asked twenty questions and generated a user model, a front controller, an
# admin subsite and a theme before you had written a line. That made the first
# five minutes impressive and the next five confusing. This leaves an
# application you can read in one sitting, and `rails generate` for the rest.

hobo_dev = ENV["HOBODEV"]

# **The setup wizard.**
#
# Hobo 2 asked twenty questions before you had written a line, and that was too
# many -- but the questions themselves were good ones, and they are the same
# ones today: how it looks, how people get accounts, whether there is an admin
# side, whether the whole thing is private, what language it speaks.
#
# So it asks, and:
#
#   - every question is also a flag, so a script never stops:
#     `hobo new blog --no-theme --invite-only --locale=es`
#   - with no terminal to ask in, every question takes its default -- which is
#     what a test does, and what `hobo new blog < /dev/null` does
#   - `--wizard` asks anyway, and `--no-wizard` never asks
#
# The defaults are the decisions of PLAN.md: theme yes, public signup, no
# activation mail, no admin subsite, not private, English.
answers = ENV["HOBO_NEW_ANSWERS"].to_s.split

interactive = if answers.include?("--wizard") then true
              elsif answers.include?("--no-wizard") then false
              else $stdin.tty?
              end

# Thor's `yes?` reads a bare Enter as "no", which makes a question whose default
# is yes impossible to answer the easy way. This reads the Enter as the default,
# which is what the brackets promise.
question = lambda do |flag, text, default|
  next false if answers.include?("--no-#{flag}")
  next true  if answers.include?("--#{flag}")
  next default unless interactive

  said = ask("#{text} [#{default ? 'S/n' : 's/N'}]").to_s.strip.downcase
  next default if said.empty?
  said.start_with?("s", "y")
end

say "\nHobo\n", :green if interactive

# **The theme is a question, with three answers.**
#
#   clean      Hobo's own: 222 lines of css over the roles the catalogue writes,
#              no framework, nothing to download. The default.
#   bootstrap  Bootstrap 5: the same pages, dressed by a table of class names.
#   none       No page and no stylesheet: Hobo paints the **body** of each page,
#              with its semantic class names, and your own layout wraps it.
#              The way in for an application that already has a design.
theme = answers.grep(/\A--theme=/).first.to_s.split("=").last
theme = "none" if answers.include?("--no-theme")
theme = "clean" if answers.include?("--theme")

if theme.blank? && interactive
  said = ask("Tema: [c]lean (el de Hobo), [b]ootstrap, [n]inguno? [c]").to_s.strip.downcase
  theme = { "b" => "bootstrap", "n" => "none" }.fetch(said[0].to_s, "clean")
end
theme = "clean" if theme.blank?

unless %w[clean bootstrap none].include?(theme)
  say "Tema desconocido: #{theme}. Son clean, bootstrap o none.", :red
  exit 1
end

with_theme = theme != "none"

# How people get an account. Both are steps of the user's lifecycle; see
# `hobo:signup`.
invite_only = question.call("invite-only", "Solo se entra por invitacion? (un administrador invita; no hay alta publica)", false)
activation_email = invite_only ? false : question.call("activation-email", "El alta tiene que confirmarse por correo?", false)

# A part of the application for administrators: another directory of
# controllers over the same models.
with_admin = question.call("admin", "Quieres un subsitio de administracion en /admin?", false)

# The old wizard's "prevent all access to the site to non-members".
private_site = question.call("private", "Todo el sitio detras del login? (si no, cada modelo decide quien ve sus paginas)", false)

# And the language.
locale = answers.grep(/\A--locale=/).first.to_s.split("=").last
locale = ask("Idioma de la aplicacion? [en]").to_s.strip if locale.blank? && interactive
locale = "en" if locale.blank?

# The names. Hobo 2 asked for all three and they are still real choices: an
# application may call its front page `home` and its administration `staff`.
named = lambda do |flag, text, default|
  given = answers.grep(/\A--#{flag}=/).first.to_s.split("=").last
  next given if given.present?
  next default unless interactive
  said = ask("#{text} [#{default}]").to_s.strip
  said.empty? ? default : said
end

front_name = named.call("front", "Como se llama el controlador de la portada?", "front")
admin_name = with_admin ? named.call("admin-name", "Como se llama el subsitio de administracion?", "admin") : "admin"

# What Hobo 2 asked as "Initial Migration: [s]kip, [g]enerate migration file
# only, generate and [m]igrate". The generator takes the same three answers.
migration = if answers.include?("--skip-migration") then "s"
            elsif answers.include?("--generate-migration") then "g"
            elsif !interactive then "m"
            else
              said = ask("Migracion inicial: [s]altar, [g]enerar el fichero, generar y [m]igrar? [m]").to_s.strip.downcase
              %w[s g m].include?(said) ? said : "m"
            end

gem_line = lambda do |name|
  hobo_dev ? %(gem "#{name}", path: "#{File.join(hobo_dev, name)}") : %(gem "#{name}")
end

# One line, because there is one gem (decision 11). It used to be six: the
# model layer, the tag runtime, the catalogue and the theme were separate, and
# an application had to name all of them to get a working application. With
# HOBODEV set it comes from the working tree instead of from rubygems.
gems = %w[hobo]

append_to_file "Gemfile", (["", "# Hobo"] + gems.map(&gem_line) + [""]).join("\n")

after_bundle do
  # Rails 8 brings its own authentication generator, and it is better than the
  # one Hobo used to carry: piece 15 of PLAN.md is delegated to it.
  # One worked example, so `bin/rails server` shows something on the first run.
  generate "hobo:resource", "story title:string body:text published_on:date"

  # Rails owns the user, the session and the passwords (piece 15). Hobo owns the
  # page that lets the first person in without a console.
  generate "authentication"
  generate "hobo:front_page", front_name
  # Rails' generator writes a session and a password reset and no registration.
  # Hobo 2 had signup in the bar and an application without it is an application
  # with exactly one user, forever.
  #
  # The two questions the old wizard asked about accounts travel from the
  # command line to here: `hobo new blog --invite-only` has to generate the
  # invitation flow instead of the public one, because afterwards the routes of
  # the public one are already drawn and taking them back out is not a
  # generator's job.
  signup_options = []
  signup_options << "--activation-email" if activation_email
  signup_options << "--invite-only" if invite_only
  generate "hobo:signup", *signup_options

  # A directory of controllers over the same models, for administrators.
  generate "hobo:admin_subsite", admin_name if with_admin

  # Without the theme there is nothing to plug into the layout: the application
  # keeps the one Rails wrote, Hobo paints the body of each page into it, and the
  # design is yours from the first minute.
  # The application says which one out loud, because it is a thing about the
  # application and not about the command that made it.
  application %(    config.hobo.theme = #{with_theme ? ":#{theme}" : "false"})

  # The language of the application, which was one of the wizard's questions too
  # (`hobo:i18n de en es fr hu it nb pt-PT ru`).
  #
  # That generator **copied Hobo's own strings into your application** -- 197
  # lines per language -- because in 2010 that was the only way to change them.
  # It is not any more: the gem is an engine and its `config/locales` are loaded
  # on their own, and an application overrides a key by having that key. So the
  # generator is gone, and what is left of the question is this line, plus a
  # file for **your** words -- which is the half of `app.<locale>.yml` that was
  # worth keeping.
  application %(    config.i18n.default_locale = :#{locale}) unless locale == "en"

  create_file "config/locales/app.#{locale}.yml", <<~YAML
    # The names your application uses for its own things. Rails looks here for
    # them, and Hobo's pages ask Rails -- so a model called `Story` becomes
    # "Relato" everywhere by saying it once, here.
    #
    # Uncomment what you need. Hobo's own strings are in the gem; to change one,
    # write the same key in a file of yours (config/locales/hobo.#{locale}.yml).
    #{locale}:
    #  activerecord:
    #    models:
    #      story:
    #        one: Story
    #        other: Stories
    #    attributes:
    #      story:
    #        title: Title
    #        body: Body
  YAML

  # "Prevent all access to the site to non-members", as the old wizard asked it.
  # Rails' filter is already on every controller; what this does is stop Hobo's
  # from stepping around it. The pages that let somebody in keep working.
  if private_site
    application %(    # Todo el sitio detras del login.\n    config.hobo.private_site = true)
  end

  # Rails renders its own views -- the session form, the password pages -- with
  # the application layout, and that layout knows nothing about the theme. So
  # those pages came out unstyled next to the ones Hobo paints. The layout gets
  # the theme's stylesheets and its container, and everything looks like one
  # application again.
  #
  # The match has to survive Rails changing its own layout: 8.1 writes
  # `stylesheet_link_tag :app, "data-turbo-track": "reload"`, and a pattern
  # anchored on `:app %>` stopped matching -- silently, because `gsub_file`
  # reports the file either way. That is how the theme came unplugged again, so
  # the line is matched by what it is, not by what it carried that year, and
  # `test_the_layout_wears_the_theme` in the conformance suite fails if it ever
  # stops matching at all.
  # Rails renders its own views -- the session form, the password pages -- with
  # the application layout, and that layout knows nothing about the theme. So
  # those pages came out unstyled next to the ones Hobo paints. The layout gets
  # the theme's stylesheets and its container, and everything looks like one
  # application again.
  #
  # The match has to survive Rails changing its own layout: 8.1 writes
  # `stylesheet_link_tag :app, "data-turbo-track": "reload"`, and a pattern
  # anchored on `:app %>` stopped matching -- silently, because `gsub_file`
  # reports the file either way.
  if with_theme
    sheets = theme == "bootstrap" ? %w[bootstrap hobo] : %w[clean]
    links = sheets.map { |sheet| %(<%= stylesheet_link_tag "#{sheet}" %>) }.join("\n\\1")

    gsub_file "app/views/layouts/application.html.erb",
              /^(\s*)<%= stylesheet_link_tag :app.*%>$/,
              "\\1#{links}\n\\0"

    gsub_file "app/views/layouts/application.html.erb",
              /<%= yield %>/,
              "<div class=\"container\">\n      <%= yield %>\n    </div>"
  end

  route "hobo_routes"

  # Rails' authentication generator leaves two migrations behind, and
  # `hobo:migration` refuses to do anything while there are pending ones: it
  # printed "You have 2 pending migrations" and stopped, and what came out was an
  # application whose very first page answered 500 with "no such table: stories".
  #
  # The `rescue nil` that used to be on the next line is why that was quiet.
  rails_command "db:migrate"
  case migration
  when "m" then generate "hobo:migration", "-n -m"
  when "g" then generate "hobo:migration", "-n -g"
  end

  say [
    "",
    "Done.",
    "",
    "  cd #{app_name}",
    "  bin/rails server",
    "",
    "There is a Story model with its pages, and not one view written: Hobo",
    "derives them from what the model says. When a page has to be different,",
    "write its template and Hobo steps aside.",
    with_theme ? "" : "Sin tema: Hobo pinta el cuerpo de cada pagina y tu layout la envuelve.",
    "",
    "The first page will ask you to create the first user.",
    "",
    "  bin/rails generate hobo:resource task title:string done:boolean",
    "",
  ].join("\n"), :green
end
