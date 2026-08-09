require "hobo_rapid/theme"

# The Clean theme, and the default one.
#
# It has **no table of class names at all**: the catalogue's own roles --
# `index-page`, `content-header`, `field-list`, `action` -- are what its
# stylesheet styles. That is the whole point of the roles being semantic, and it
# is why this file is four lines: a theme that agrees with the markup does not
# have to say anything about it.
#
# It is the default because it depends on nothing: no framework to download, no
# class names from somebody else in your html. `--theme=bootstrap` gets you
# Bootstrap; `--theme=none` gets you the roles and your own stylesheet.
module HoboClean

  HoboRapid::Theme.wears("clean")

end
