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

# The questions the old setup wizard asked.
#
# They did not disappear with the wizard -- what disappeared is being asked
# twenty of them before you had written a line. Each one is a flag with a
# default, and the template only *asks* when there is somebody to answer:
# `hobo new --no-theme blog` never stops, and neither does a test.
answers = ENV["HOBO_NEW_ANSWERS"].to_s.split

# **The theme is a question.** Answer no and what comes out is a plain Rails
# application: Hobo still derives every page from the model, but it paints the
# body and nothing else, and your own layout wraps it. That is the way in for an
# application that already has a design -- and the way to start bare and add
# your own.
with_theme = if answers.include?("--no-theme") then false
             elsif answers.include?("--theme") then true
             elsif $stdin.tty? then yes?("Quieres el tema de Hobo? Si dices que no, la aplicacion sale sin estilos y el diseno lo pones tu. [S/n]")
             else true
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
  generate "hobo:front_page"
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
  signup_options << "--activation-email" if answers.include?("--activation-email")
  signup_options << "--invite-only" if answers.include?("--invite-only")
  generate "hobo:signup", *signup_options

  # Without the theme there is nothing to plug into the layout: the application
  # keeps the one Rails wrote, Hobo paints the body of each page into it, and the
  # design is yours from the first minute.
  unless with_theme
    application %(    # Hobo pinta el cuerpo de cada pagina; el layout es tuyo.\n    config.hobo.theme = false)
  end

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
  locale = answers.grep(/\A--locale=/).first.to_s.split("=").last
  if locale.present?
    application %(    config.i18n.default_locale = :#{locale})
  end

  create_file "config/locales/app.#{locale.presence || 'en'}.yml", <<~YAML
    # The names your application uses for its own things. Rails looks here for
    # them, and Hobo's pages ask Rails -- so a model called `Story` becomes
    # "Relato" everywhere by saying it once, here.
    #
    # Uncomment what you need. Hobo's own strings are in the gem; to change one,
    # write the same key in a file of yours (config/locales/hobo.#{locale.presence || 'en'}.yml).
    #{locale.presence || 'en'}:
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
  if answers.include?("--private")
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
  if with_theme
    gsub_file "app/views/layouts/application.html.erb",
              /^(\s*)<%= stylesheet_link_tag :app.*%>$/,
              "\\1<%= stylesheet_link_tag \"bootstrap\" %>\n\\1<%= stylesheet_link_tag \"hobo\" %>\n\\0"

    gsub_file "app/views/layouts/application.html.erb",
              /<%= yield %>/,
              "<div class=\"container py-4\">\n      <%= yield %>\n    </div>"
  end

  route "hobo_routes"

  # Rails' authentication generator leaves two migrations behind, and
  # `hobo:migration` refuses to do anything while there are pending ones: it
  # printed "You have 2 pending migrations" and stopped, and what came out was an
  # application whose very first page answered 500 with "no such table: stories".
  #
  # The `rescue nil` that used to be on the next line is why that was quiet.
  rails_command "db:migrate"
  generate "hobo:migration", "-n -m"

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
