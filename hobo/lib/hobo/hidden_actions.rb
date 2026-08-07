module Hobo

  # What `hide_action` used to do, and Rails 5 took away: keep the helper methods
  # a controller mixes in from becoming actions anybody can request over HTTP.
  #
  # It lives on its own because **any** controller that receives a Hobo helper
  # needs it, not only the ones that include Hobo::Controller. Assuming otherwise
  # was a real bug: a controller with the helpers but not the controller module
  # -- and applications do have those -- blew up on every request with
  # `undefined method 'hobo_hidden_action_methods'`.
  module HiddenActions

    def self.extended(base)
      base.singleton_class.prepend(ActionMethods)
    end

    def hobo_hidden_action_methods
      @hobo_hidden_action_methods ||=
        if superclass.respond_to?(:hobo_hidden_action_methods)
          superclass.hobo_hidden_action_methods.dup
        else
          Set.new
        end
    end

    module ActionMethods
      def action_methods
        super - hobo_hidden_action_methods
      end
    end

  end

end
