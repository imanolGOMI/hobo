require "rails"

module HoboBootstrap

  # A Rails engine so the theme's stylesheet is served from the gem: an
  # application does not have to copy anything to look like something.
  class Engine < ::Rails::Engine

    initializer "hobo_bootstrap.assets" do |app|
      next unless app.config.respond_to?(:assets)
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.precompile += %w[bootstrap.css hobo.css]
    end

  end

end
