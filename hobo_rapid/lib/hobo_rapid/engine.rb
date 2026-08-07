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

    initializer "hobo_rapid.derive" do |app|
      app.config.to_prepare do
        next unless defined?(Hobo::Model)
        Hobo::Model.all_models.each { |model| HoboRapid::Derivation.derive(model) }
      end
    end

  end

end
