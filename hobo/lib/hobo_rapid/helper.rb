# The bridge from a Rails view to the tag runtime.
#
#   <%= rapid_tag :show_page, @story %>
#
# That is all an application needs to paint a derived page. `this` is passed
# explicitly rather than read from an instance variable, because a template that
# says what it is painting is easier to follow than one that does not.

require "rapid"
require "hobo_rapid/request"

module HoboRapid

  module Helper

    # `this` left out is not `this` set to nothing. A tag written inside a param
    # of another tag is painting whatever that tag is painting -- a
    # `<filter-menu>` inside a list is a menu **for that list** -- and passing
    # nil wiped it, so the tag could not even find the model and came out empty.
    INHERIT = Object.new.freeze

    def rapid_tag(name, this = INHERIT, **attributes)
      # `respond_to?` with one argument does not see protected methods, and in a
      # controller `form_authenticity_token` is protected -- so the token came
      # back nil and every form Hobo painted got 422.
      token = send(:form_authenticity_token) if respond_to?(:form_authenticity_token, true)
      user = send(:current_user) if respond_to?(:current_user, true)
      user = rails_session_user if user.nil?

      # Hobo's `current_user` never answers nil: it answers a `Guest`, an object
      # that says no to everything. That is right for the model layer, which
      # asks it questions -- and wrong here, because a generated model says
      # `acting_user.present?`, and a Guest **is present**. So a stranger was
      # offered an edit and a delete on every row. For the tags, nobody is nil.
      user = nil if user.respond_to?(:guest?) && user.guest?
      messages = flash.to_h.symbolize_keys if respond_to?(:flash, true) && flash

      query = request.query_parameters if respond_to?(:request, true) && request

      # A subsite is a namespace of controllers (`Admin::StoriesController`), and
      # that is the only place the name lives -- there is nothing to register.
      subsite = self.class.name.to_s.split("::").first.underscore if self.class.name.to_s.include?("::")

      # A `Rapid::Parameter` is a param, anything else is an attribute. In DRYML
      # the two were told apart by syntax -- `<heading:>...</heading:>` against
      # `class="big"` -- and here the value says which it is, which keeps the
      # call site short:
      #
      #   <%= rapid_tag :index_page, @movies,
      #         :filters => Rapid.markup { call_tag(:search_filter) } %>
      params, attributes = attributes.partition { |_, value| value.is_a?(Rapid::Parameter) }
                                     .map(&:to_h)

      HoboRapid.with_request(token, user, messages || {}, query || {}, subsite) do
        if this.equal?(INHERIT)
          Rapid.render(name, attributes, **params).html_safe
        else
          Rapid.render(name, attributes, :this => this, **params).html_safe
        end
      end
    end

    private

    # Who Rails says you are, on a controller that never asked Hobo anything.
    #
    # A front page or a signup page is a plain `ApplicationController`: it does
    # not include `Hobo::Controller::Model`, so it has no `current_user` at all,
    # and it says `allow_unauthenticated_access` -- which in Rails 8 is a
    # `skip_before_action :require_authentication`, and **resuming the session
    # happens inside that filter**. So Rails had not looked at the cookie
    # either.
    #
    # Between the two, the bar on the front page said "Log in" to somebody who
    # had just registered, and creating the first user looked like it had
    # failed. It had not: the user was in the database and the session row with
    # it.
    def rails_session_user
      return nil unless defined?(::Current)
      send(:resume_session) if ::Current.try(:session).nil? && respond_to?(:resume_session, true)
      ::Current.try(:user) || ::Current.try(:session)&.try(:user)
    rescue StandardError
      nil
    end

  end
end

if defined?(ActiveSupport)
  # In views, obviously. And in controllers, because a controller that paints a
  # tag directly is a normal thing to do -- Hobo's own derived pages do it.
  ActiveSupport.on_load(:action_view) { include HoboRapid::Helper }
  ActiveSupport.on_load(:action_controller) { include HoboRapid::Helper }

  # And the verbs a view retouches the derived page with, which are DRYML's
  # params translated (hobo_rapid/params.rb).
  #
  # `prepend` and not `include` because a view context has another
  # `method_missing` above ours -- the one Rails puts there to load the routes
  # the first time a route helper is named (railties, lazy_route_set.rb). That
  # one gives way with `super`, so included would reach us too; prepended does
  # not depend on it going on giving way.
  ActiveSupport.on_load(:action_view) { prepend HoboRapid::Params }
  ActiveSupport.on_load(:action_controller) { prepend HoboRapid::Params }
end
