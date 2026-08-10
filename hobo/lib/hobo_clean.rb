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

  # No table of class names at all: this theme's stylesheet styles the
  # catalogue's own roles.
  def self.dress(subsite = nil)
    HoboRapid::Theme.wears("clean", :subsite => subsite)
  end

end

# Y se apunta, como cualquier otro tema. Que venga dentro de la gema no le da
# ningun privilegio: el nucleo mira el registro y no conoce nombres.
Hobo.theme(:clean) { |subsite| HoboClean.dress(subsite) }
