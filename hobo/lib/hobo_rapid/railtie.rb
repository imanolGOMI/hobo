require 'hobo_rapid'
require 'rails'
module HoboRapid
  class Railtie < Rails::Railtie

    # At the end of each request, the params nobody claimed.
    #
    # Here and not inside the tag: a tag cannot tell whether the caller got the
    # name wrong or whether an extension further down is going to claim it. Once
    # the request is over there is no doubt left, and it is all said at once
    # rather than one stray line in the middle of a page.
    initializer "hobo_rapid.unclaimed_params" do
      ActiveSupport::Notifications.subscribe("process_action.action_controller") do
        Hobo.warn_about_unclaimed_params if defined?(Hobo) && Hobo.respond_to?(:warn_about_unclaimed_params)
      end
    end

  end
end
