require "rails"
require "hobo_rapid"

module HoboRapid

  # Deriving the pages of every model, on boot and on every reload.
  #
  # An application should not have to ask: declaring the model is the ask. And
  # it has to happen on *every* reload, because a model that gains a field in
  # development has to gain the column on its pages without a restart.
  #
  # `to_prepare` runs after the autoloader has been reset, so asking for the
  # models here is what makes Zeitwerk load them -- which is the eager loading
  # that PLAN.md flagged as the aggravation of this whole layer.
  class Engine < ::Rails::Engine

    # The Stimulus half of the catalogue, handed to the application.
    #
    # Four controllers were ported to Stimulus in layer 5, each with its own
    # browser test, and **no application loaded a single one of them**: an
    # engine's `app/javascript` is not on anybody's path, and an engine's pins
    # are not in anybody's import map unless it says so. So `<input-many>`
    # painted its rows and its buttons, and pressing them did nothing.
    #
    # It is the theme all over again: the piece existed and the product did not
    # have it. `eagerLoadControllersFrom("controllers", ...)` in the generated
    # application picks these up because they are pinned *under the same name*.
    initializer "hobo_rapid.importmap", :before => "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    initializer "hobo_rapid.derive" do |app|
      app.config.to_prepare do
        next unless defined?(Hobo::Model)
        Hobo::Model.all_models.each { |model| HoboRapid::Derivation.derive(model) }
      end
    end

  end

end
