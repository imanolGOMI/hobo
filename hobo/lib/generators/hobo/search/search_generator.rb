require "rails/generators"

module Hobo
  module Generators

    # `rails generate hobo:search`
    #
    # The box in the bar that searches the whole site, and the page that answers.
    #
    # Hobo 2 had this on every page (`<live-search>`, hooked to `site_search`),
    # and the engine that does the looking -- `Hobo.find_by_search`, over every
    # model that declares search columns -- is still here and untouched. What was
    # missing was the two ends: somewhere to type and somewhere to read.
    #
    # As everywhere else, **the route is the switch**: no route, no box in the
    # bar, and nothing to turn off.
    class SearchGenerator < Rails::Generators::Base

      source_root File.expand_path("templates", __dir__)

      def create_controller
        template "search_controller.rb.erb", "app/controllers/search_controller.rb"
      end

      def add_the_route
        route %(get "/search" => "search#index", as: :site_search)
      end

      def say_what_happened
        say [
          "",
          "La busqueda esta en /search, y la barra la ofrece en todas las paginas.",
          "",
          "Busca en los modelos que declaren columnas de busqueda; si no lo dicen,",
          "Hobo lo adivina de las que tengan (name, title, body, description...):",
          "",
          "  set_search_columns :titulo, :sinopsis",
          "",
        ].join("\n"), :green
      end

    end

  end
end
