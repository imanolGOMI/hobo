module HoboHelperBase

    def add_to_controller(controller)
      controller.send(:include, self)
      # `hide_action` went away in Rails 5. It mattered: everything public that a
      # controller picks up becomes a routable action, so without it every helper
      # method here would be reachable over HTTP. The names are collected instead
      # and subtracted in Hobo::Controller::ClassMethods#action_methods.
      controller.hobo_hidden_action_methods.merge(instance_methods.map(&:to_s))
    end

end
