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

gem_line = lambda do |name|
  hobo_dev ? %(gem "#{name}", path: "#{File.join(hobo_dev, name)}") : %(gem "#{name}")
end

# With HOBODEV set, every gem comes from the working tree: `hobo` depends on
# hobo_support, hobo_fields and dryml, and none of those are published while the
# port is under way. Once they are one gem (decision 11) this is one line.
gems = hobo_dev ? %w[hobo_support hobo_fields dryml hobo hobo_rapid hobo_bootstrap]
                : %w[hobo hobo_rapid hobo_bootstrap]

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
  gsub_file "app/views/layouts/application.html.erb",
            /^(\s*)<%= stylesheet_link_tag :app.*%>$/,
            "\\1<%= stylesheet_link_tag \"bootstrap\" %>\n\\1<%= stylesheet_link_tag \"hobo\" %>\n\\0"

  gsub_file "app/views/layouts/application.html.erb",
            /<%= yield %>/,
            "<div class=\"container py-4\">\n      <%= yield %>\n    </div>"

  route "hobo_routes"

  generate "hobo:migration", "-n -m" rescue nil

  say [
    "",
    "Listo.",
    "",
    "  cd #{app_name}",
    "  bin/rails server",
    "",
    "Hay un modelo Story con sus paginas, y no hay ni una vista escrita: las",
    "deriva Hobo de lo que dice el modelo. Cuando una pagina tenga que ser",
    "distinta, escribe su plantilla y Hobo se aparta.",
    "",
    "Al abrirla te pedira crear el primer usuario.",
    "",
    "  bin/rails generate hobo:resource task title:string done:boolean",
    "",
  ].join("\n"), :green
end
