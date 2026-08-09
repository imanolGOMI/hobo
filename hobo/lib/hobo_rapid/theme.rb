require "rapid"

module HoboRapid

  # What a theme is, in Hobo 3.
  #
  # Two things and no more: **a table of class names** (what the catalogue's
  # roles look like -- `Rapid.class_map`) and **a list of stylesheets** for
  # `<page>` to link. No tags of its own, no markup, no taglib to include.
  #
  # That is what makes a second theme possible at all. In Hobo 2 a theme was a
  # gem full of DRYML that redefined the pages, so `hobo_clean` and
  # `hobo_bootstrap` each carried their own copy of every page -- and in Hobo 3,
  # until now, `<page>` itself lived inside the Bootstrap theme, which is the
  # same problem with fewer files.
  #
  # A theme that wants to go further can still define tags: it is a plugin like
  # any other (piece 17). This is only the part every theme needs.
  module Theme

    class << self

      # The stylesheets `<page>` links, in order. The application's own goes
      # after these, so it can override them.
      def stylesheets = @stylesheets ||= []

      # `HoboRapid::Theme.wears "clean", "index-page" => "wide"`
      def wears(*sheets, **classes)
        stylesheets.concat(sheets.map(&:to_s))
        Rapid.dress_with(classes) if classes.any?
        self
      end

      # For tests, and for an application that wants to start from nothing.
      def undress
        @stylesheets = []
        Rapid.class_map.clear
      end

    end

  end

end
