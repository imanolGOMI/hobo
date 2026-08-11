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

# Where a gem is inside HOBODEV. `hobo` is nested -- the repository is
# `hobo/` and the gem inside it is `hobo/hobo/` -- and the others are not.
# Guessing `HOBODEV/<name>` for all of them wrote a path that does not exist,
# and the application only found out at `bundle install`.
gem_path = lambda do |name|
  [File.join(hobo_dev, name, name), File.join(hobo_dev, name)]
    .find { |candidate| File.exist?(File.join(candidate, "#{name}.gemspec")) }
end

gem_line = lambda do |name|
  path = hobo_dev && gem_path.call(name)
  path ? %(gem "#{name}", path: "#{path}") : %(gem "#{name}")
end

# One line, because there is one gem (decision 11). It used to be six: the
# model layer, the tag runtime, the catalogue and the theme were separate, and
# an application had to name all of them to get a working application. With
# HOBODEV set it comes from the working tree instead of from rubygems.
gems = %w[hobo]

append_to_file "Gemfile", (["", "# Hobo"] + gems.map(&gem_line) + [""]).join("\n")

after_bundle do
  # There used to be a `Story` model here -- "one worked example, so
  # `bin/rails server` shows something on the first run". It came out: **Hobo 2
  # never created a model you had not asked for**, and this one arrived before
  # the wizard had asked anything, so what you watched go by was a user model, a
  # question about a migration, and a model called Story appearing in it. An
  # application you did not write is not a nice welcome, it is something to
  # delete before you start.
  #
  # Rails owns the user, the session and the passwords (piece 15).
  generate "authentication"

  # **La base de datos no se toca aquí.** Antes había un `db:migrate` en este
  # punto -- las dos migraciones que escribe el generador de autenticación de
  # Rails, y sin ellas `hobo:migration` se niega a trabajar-- y el resultado era
  # que `hobo new` migraba la base sin preguntar y luego el asistente preguntaba
  # por una migración que ya no tenía nada que hacer. Ahora las dos cosas son la
  # misma pregunta, y la hace el asistente al final.
  #
  # And the wizard does the rest: the questions, and what the answers mean --
  # the initial migration among them, which is why there is nothing after this.
  generate "hobo:setup_wizard", *answers.map { |a| a.sub(/\A--no-theme\z/, "--theme=none") }

  say [
    "",
    "Done.",
    "",
    "  cd #{app_name}",
    "  bin/rails server",
    "",
    "La primera pagina te pedira que crees el primer usuario.",
    "",
    "Y para el primer modelo, con sus paginas y sin escribir una vista:",
    "",
    "  bin/rails generate hobo:resource task title:string done:boolean",
    "  bin/rails generate hobo:migration",
    "",
    "Y si mas adelante quieres cambiar de tema, anadir un subsitio o cerrar el",
    "sitio con llave, las mismas preguntas siguen ahi:",
    "",
    "  bin/rails generate hobo:setup_wizard",
    "",
  ].join("\n"), :green
end
