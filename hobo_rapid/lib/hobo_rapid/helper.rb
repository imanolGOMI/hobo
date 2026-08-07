# The bridge from a Rails view to the tag runtime.
#
#   <%= rapid_tag :show_page, @story %>
#
# That is all an application needs to paint a derived page. `this` is passed
# explicitly rather than read from an instance variable, because a template that
# says what it is painting is easier to follow than one that does not.

require "rapid"

module HoboRapid

  # The tag runtime does not know about requests, and a form still needs the
  # forgery token of *this* one. The bridge hands it over for the length of the
  # render: a tag can ask for it without any tag knowing what a controller is.
  #
  # A form without it gets 422 from Rails and nothing says why, which is the
  # kind of failure that eats an afternoon.
  class << self

    def with_request(token, user, flash = {})
      previous = [Thread.current[:hobo_rapid_token], Thread.current[:hobo_rapid_user],
                  Thread.current[:hobo_rapid_flash]]
      Thread.current[:hobo_rapid_token] = token
      Thread.current[:hobo_rapid_user] = user
      Thread.current[:hobo_rapid_flash] = flash
      yield
    ensure
      Thread.current[:hobo_rapid_token], Thread.current[:hobo_rapid_user],
        Thread.current[:hobo_rapid_flash] = previous
    end

    def authenticity_token = Thread.current[:hobo_rapid_token]
    def current_user = Thread.current[:hobo_rapid_user]
    def flash_messages = Thread.current[:hobo_rapid_flash] || {}

  end

  module Helper

    def rapid_tag(name, this = nil, **attributes)
      # `respond_to?` with one argument does not see protected methods, and in a
      # controller `form_authenticity_token` is protected -- so the token came
      # back nil and every form Hobo painted got 422.
      token = send(:form_authenticity_token) if respond_to?(:form_authenticity_token, true)
      user = send(:current_user) if respond_to?(:current_user, true)
      messages = flash.to_h.symbolize_keys if respond_to?(:flash, true) && flash

      HoboRapid.with_request(token, user, messages || {}) do
        Rapid.render(name, attributes, :this => this).html_safe
      end
    end

  end
end

if defined?(ActiveSupport)
  # In views, obviously. And in controllers, because a controller that paints a
  # tag directly is a normal thing to do -- Hobo's own derived pages do it.
  ActiveSupport.on_load(:action_view) { include HoboRapid::Helper }
  ActiveSupport.on_load(:action_controller) { include HoboRapid::Helper }
end
