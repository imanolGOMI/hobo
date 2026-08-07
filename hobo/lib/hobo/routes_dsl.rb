require 'hobo/routes'

module Hobo

  # `hobo_routes`, for an application's own config/routes.rb:
  #
  #     Rails.application.routes.draw do
  #       hobo_routes
  #       root :to => "front#index"
  #     end
  #
  # This replaces `config/hobo_routes.rb`, the generated file Hobo used to write
  # at boot and hand to the routes reloader. The file was a problem in three
  # separate ways:
  #
  #   - it was written **during boot**, so booting needed a writable disk, and
  #     a read-only deployment had a flag of its own to work around it;
  #   - it went into the repository looking like something to edit, with a
  #     "don't edit!" banner on top saying it was not;
  #   - and its routes were loaded in a fixed place, so an application could not
  #     decide what came before or after them.
  #
  # Saying `hobo_routes` puts them exactly where the application wants them, and
  # they are rebuilt whenever Rails reloads the routes, like everybody else's.
  #
  # What decides *which* routes exist has not changed: it is still the Router
  # (lib/generators/hobo/routes/router.rb), which reads each controller's
  # auto_actions, its owner associations, its lifecycles and its web methods.
  module RoutesDsl

    def hobo_routes
      # Required here, not at the top: these pull in ActionController, and this
      # file is loaded while the application is still booting.
      require 'hobo/controller/model'
      require 'hobo/controller/user_base'
      require 'generators/hobo/routes/router'

      Hobo::Routes.reset_linkables

      Hobo::RouteSource.new.each_subsite do |subsite, source|
        if subsite
          namespace(subsite) { instance_eval(source, "hobo_routes (#{subsite})", 1) }
        else
          instance_eval(source, "hobo_routes", 1)
        end
      end
    end

  end

  # Builds the route declarations for each subsite.
  #
  # The Router hands back fragments of route DSL as text, which used to be
  # written to a file and read back by Rails. They are evaluated straight into
  # the mapper now -- the same thing Rails does with config/routes.rb, minus the
  # trip through the disk.
  class RouteSource

    def each_subsite
      ([nil] + Hobo.subsites).each do |subsite|
        source = source_for(subsite)
        yield(subsite, source) unless source.blank?
      end
    end

    private

    def source_for(subsite)
      controllers_for(subsite).map { |controller| source_for_controller(subsite, controller) }.join
    end

    def source_for_controller(subsite, controller)
      router = Generators::Hobo::Routes::Router.new(subsite, controller)

      source = +"# #{controller.controller_path}\n"
      source << router.emit_hash(router.resources_hash, "")
      router.owner_actions.each { |owner| source << router.emit_hash(owner, "") }
      router.user_routes.each { |route| source << "#{route}\n" }
      source
    end

    def controllers_for(subsite)
      Hobo::Controller::Model.all_controllers(subsite, :force).select { |c| c < Hobo::Controller::Model }
    end

  end

end

# The mapper is part of ActionPack and is already there by the time an
# application draws its routes; hooking this on :action_controller meant
# `hobo_routes` only existed if something had touched a controller first.
require 'action_dispatch'
ActionDispatch::Routing::Mapper.include(Hobo::RoutesDsl)
