require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:assets [--theme=clean]`
    #
    # Brings the theme's stylesheet **into your application**, so you can change
    # it. From then on it is yours: the application's own assets come before the
    # gem's, so the copy is what gets served and nothing of Hobo's overrides it.
    #
    # In Hobo 2 this copied `application.dryml`, `front_site.dryml`,
    # `dryml-support.js` and a `Guest` model, because a Hobo application needed
    # all of that to exist before it could run. None of those exist now -- the
    # tags are Ruby, the JavaScript is in the import map and the guest is an
    # object in the gem -- and what is left of the idea is the useful half:
    # **the css is yours if you want it**.
    class AssetsGenerator < Rails::Generators::Base

      class_option :theme, :type => :string,
                   :desc => "De que tema (por defecto: el que lleve la aplicacion)"

      def copy_the_stylesheets
        sheets.each do |sheet|
          source = File.join(Hobo.root, "app", "assets", "stylesheets", "#{sheet}.css")
          next say("  no encuentro #{sheet}.css en la gema", :red) unless File.exist?(source)
          create_file "app/assets/stylesheets/#{sheet}.css", File.read(source)
        end
      end

      def say_what_happened
        say [
          "",
          "Las hojas del tema estan ahora en app/assets/stylesheets, y son tuyas:",
          "lo que hay en la aplicacion se sirve antes que lo que trae la gema.",
          "",
          "Para volver atras, borra el fichero.",
          "",
        ].join("\n"), :green
      end

      private

      # Only the theme's own. `bootstrap.css` is Bootstrap itself -- 228 KB of
      # somebody else's library -- and copying that into an application is not
      # editing a theme, it is forking Bootstrap.
      def sheets
        theme = options[:theme].presence || current_theme
        theme == "bootstrap" ? %w[hobo] : %w[clean]
      end

      def current_theme
        config = File.join(destination_root, "config", "application.rb")
        return "clean" unless File.exist?(config)
        File.read(config)[/config\.hobo\.theme\s*=\s*[:"]?(\w+)/, 1] || "clean"
      end

    end

  end
end
