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

# The questions are **not asked here**: they are `hobo:setup_wizard`, which is a
# generator you can also run later, in an application that already exists. That
# is the half Hobo 2 had and this had lost -- and it is exactly what somebody
# who has just added the gem to their own application needs.
#
# So this template does the part that only makes sense while creating: the gem
# in the Gemfile, one worked example, Rails' own authentication, and then it
# hands the answers over.
answers = ENV["HOBO_NEW_ANSWERS"].to_s.split

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
  # One worked example, so `bin/rails server` shows something on the first run.
  generate "hobo:resource", "story title:string body:text published_on:date"

  # Rails owns the user, the session and the passwords (piece 15).
  generate "authentication"

  # And the wizard does the rest: the questions, and what the answers mean.
  generate "hobo:setup_wizard", *answers.map { |a| a.sub(/\A--no-theme\z/, "--theme=none") }

  # Rails' authentication generator leaves two migrations behind, and
  # `hobo:migration` refuses to do anything while there are pending ones: it
  # printed "You have 2 pending migrations" and stopped, and what came out was an
  # application whose very first page answered 500 with "no such table: stories".
  rails_command "db:migrate"
  generate "hobo:migration", "-n -m" unless answers.include?("--skip-migration")

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
    "Y si mas adelante quieres cambiar de tema, anadir un subsitio o cerrar el",
    "sitio con llave, las mismas preguntas siguen ahi:",
    "",
    "  bin/rails generate hobo:setup_wizard",
    "",
  ].join("\n"), :green
end
