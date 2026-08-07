# The bridge from a Rails view to the tag runtime.
#
#   <%= rapid_tag :show_page, @story %>
#
# That is all an application needs to paint a derived page. `this` is passed
# explicitly rather than read from an instance variable, because a template that
# says what it is painting is easier to follow than one that does not.

require "rapid"

module HoboRapid
  module Helper

    def rapid_tag(name, this = nil, **attributes)
      Rapid.render(name, attributes, :this => this).html_safe
    end

  end
end

ActiveSupport.on_load(:action_view) { include HoboRapid::Helper } if defined?(ActiveSupport)
