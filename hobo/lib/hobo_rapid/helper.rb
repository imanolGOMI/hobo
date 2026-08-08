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

    def rapid_tag(name, this = nil, **attributes)
      # `respond_to?` with one argument does not see protected methods, and in a
      # controller `form_authenticity_token` is protected -- so the token came
      # back nil and every form Hobo painted got 422.
      token = send(:form_authenticity_token) if respond_to?(:form_authenticity_token, true)
      user = send(:current_user) if respond_to?(:current_user, true)

      # Hobo's `current_user` never answers nil: it answers a `Guest`, an object
      # that says no to everything. That is right for the model layer, which
      # asks it questions -- and wrong here, because a generated model says
      # `acting_user.present?`, and a Guest **is present**. So a stranger was
      # offered an edit and a delete on every row. For the tags, nobody is nil.
      user = nil if user.respond_to?(:guest?) && user.guest?
      messages = flash.to_h.symbolize_keys if respond_to?(:flash, true) && flash

      query = request.query_parameters if respond_to?(:request, true) && request

      # A `Rapid::Parameter` is a param, anything else is an attribute. In DRYML
      # the two were told apart by syntax -- `<heading:>...</heading:>` against
      # `class="big"` -- and here the value says which it is, which keeps the
      # call site short:
      #
      #   <%= rapid_tag :index_page, @movies,
      #         :filters => Rapid.markup { call_tag(:search_filter) } %>
      params, attributes = attributes.partition { |_, value| value.is_a?(Rapid::Parameter) }
                                     .map(&:to_h)

      HoboRapid.with_request(token, user, messages || {}, query || {}) do
        Rapid.render(name, attributes, :this => this, **params).html_safe
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
