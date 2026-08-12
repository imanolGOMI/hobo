require "set"
require File.expand_path("../../lib/hobo/hidden_actions", __dir__)

module HoboHelperBase

    def add_to_controller(controller)
      controller.send(:include, self)

      # `hide_action` went away in Rails 5, and it mattered: everything public
      # that a controller picks up becomes a routable action, so without a
      # replacement `object_url` and friends would be reachable over HTTP.
      #
      # The controller is extended here rather than assumed to be ready: a
      # controller can receive these helpers without going through
      # Hobo::Controller, and it used to break on every request when it did.
      controller.extend(Hobo::HiddenActions) unless controller.respond_to?(:hobo_hidden_action_methods)
      controller.hobo_hidden_action_methods.merge(instance_methods.map(&:to_s))
    end

end
