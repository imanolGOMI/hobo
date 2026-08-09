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
  generate "hobo:signup"

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
    "",
    "The first page will ask you to create the first user.",
    "",
    "  bin/rails generate hobo:resource task title:string done:boolean",
    "",
  ].join("\n"), :green
end
