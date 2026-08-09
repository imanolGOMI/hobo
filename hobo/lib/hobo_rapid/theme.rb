require "rapid"
require "hobo_rapid/request"

module HoboRapid

  # What a theme is, in Hobo 3.
  #
  # Two things and no more: **a table of class names** (what the catalogue's
  # roles look like) and **a list of stylesheets** for `<page>` to link. No tags
  # of its own, no markup, no taglib to include.
  #
  # That is what makes a second theme possible at all. In Hobo 2 a theme was a
  # gem full of DRYML that redefined every page, so `hobo_clean` and
  # `hobo_bootstrap` each carried their own copy of all of them -- and in Hobo 3,
  # until this, `<page>` itself lived inside the Bootstrap theme, which is the
  # same problem with fewer files.
  #
  # **And a subsite can wear a different one.** Hobo 2 asked for the admin
  # subsite's theme separately, and that was a real question: an administration
  # is a different kind of place. A theme is registered under a subsite name --
  # `nil` for the site itself -- and the runtime picks by whichever part of the
  # application is painting.
  #
  # A theme that wants to go further can still define tags: it is a plugin like
  # any other (piece 17). This is only the part every theme needs.
  module Theme

    Wardrobe = Struct.new(:stylesheets, :classes)

    class << self

      def wardrobes = @wardrobes ||= Hash.new { |h, k| h[k] = Wardrobe.new([], {}) }

      # `HoboRapid::Theme.wears "clean"`
      # `HoboRapid::Theme.wears "bootstrap", "hobo", :subsite => "admin", "action" => "btn"`
      def wears(*sheets, subsite: nil, **classes)
        wardrobe = wardrobes[subsite && subsite.to_s]
        wardrobe.stylesheets.concat(sheets.map(&:to_s))
        wardrobe.classes.merge!(classes.transform_keys(&:to_s))
        self
      end

      # What the part of the application that is painting right now wears. A
      # subsite with no wardrobe of its own wears the site's, which is what
      # "the admin looks like the rest unless you say otherwise" means.
      def current = wardrobes.key?(HoboRapid.subsite) ? wardrobes[HoboRapid.subsite] : wardrobes[nil]

      def stylesheets = current.stylesheets

      def classes = current.classes

      # Every stylesheet any part of the application might link. The asset
      # pipeline has to precompile them all: which one is used is a question
      # asked per request, and precompiling happens once.
      def all_stylesheets = wardrobes.values.flat_map(&:stylesheets).uniq

      # For tests, and for an application that wants to start from nothing.
      def undress
        @wardrobes = nil
        self
      end

    end

  end

end

# The runtime carries the mechanism and Hobo says what goes in it: `dress` asks
# this for the table, so a subsite painting its own pages gets its own names.
Rapid.class_map_source = -> { HoboRapid::Theme.classes }
