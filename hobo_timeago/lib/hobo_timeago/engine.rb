require "rails/engine"

module HoboTimeago

  # The engine of a plugin does one thing: put the gem's assets where the
  # application's asset pipeline and import map can see them. An engine's
  # `app/javascript` is on nobody's path and its pins are in nobody's import map
  # unless it says so -- the same two initializers Hobo's own engine carries,
  # which is what makes this a *contract* and not a special case.
  class Engine < ::Rails::Engine

    initializer "hobo_timeago.importmap", :before => "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    initializer "hobo_timeago.assets" do |app|
      next unless app.config.respond_to?(:assets)
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.precompile += %w[hobo_timeago.css]
    end

  end

end
