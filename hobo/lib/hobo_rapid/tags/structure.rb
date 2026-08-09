# The structural tags: piece 13a.
#
# These used to live in the Bootstrap theme, and they should never have: a flash
# message, a list of validation errors, the transitions a record offers -- those
# are things a Hobo application *has*, whatever it looks like. A theme decides
# how they look; it should not decide whether they exist.
#
# Moving them here means an application with no theme still has them, and a
# second theme does not have to reimplement them to keep working.

require "rapid"
require "hobo_rapid/translation"
require "hobo_rapid/tags/views"
require "hobo_rapid/helper"

module HoboRapid
  module Tags

    module StructureSupport

      # Supplied by the controller in an application; empty in isolation.
      def flash_messages = HoboRapid.flash_messages
      def current_user = HoboRapid.current_user

      # Every form Hobo paints carries it, because Rails answers 422 without it.
      def authenticity_token_field
        token = HoboRapid.authenticity_token
        return unless token
        tag("input", { :type => "hidden", :name => "authenticity_token", :value => token })
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::StructureSupport)

# One flash message of a given kind. The kinds are the application's -- :notice,
# :error, whatever it puts there -- not a fixed list.
Rapid.define(:flash_message, :attrs => [:type]) do
  kind = (attributes[:type] || :notice).to_sym
  message = flash_messages[kind] || flash_messages[kind.to_s]
  next if message.blank?

  tag("div", { :class => "flash flash-#{kind}", :role => "alert" }, :message) { text message }
end

# Every message the application left, in the order it left them.
Rapid.define(:flash_messages) do
  tag("div", { :class => "flash-messages" }, :messages) do
    flash_messages.each_key do |kind|
      call_tag(:flash_message, { :type => kind }, :as => :"#{kind}_message")
    end
  end
end

# Why a record could not be saved. Painted only when there is something to say,
# so a form does not carry an empty box about.
Rapid.define(:error_messages) do
  errors = this.respond_to?(:errors) ? this.errors : nil
  next if errors.nil? || errors.empty?

  count = errors.size
  model = this.class.respond_to?(:model_name) ? this.class.model_name.human : this.class.name

  tag("section", { :class => "error-messages", :role => "alert" }, :errors) do
    tag("h2", {}, :heading) do
      text(count == 1 ? t(:"errors.one", "1 error stopped this %{name} from being saved", :name => model)
                      : t(:"errors.many", "%{count} errors stopped this %{name} from being saved",
                          :count => count, :name => model))
    end
    tag("ul", {}, :list) do
      errors.to_a.each { |message| tag("li", {}, :item) { text message.to_s } }
    end
  end
end

# The moves a record offers *this* user right now. It is the lifecycle of piece
# 5 seen from the page, and it is the reason lifecycles are worth having: the
# buttons are not written anywhere, they are what the record can do.
Rapid.define(:transition_buttons) do
  next unless this.respond_to?(:lifecycle) && this.lifecycle

  transitions = this.lifecycle.available_transitions_for(current_user)
  next if transitions.blank?

  tag("div", { :class => "transitions" }, :transitions) do
    transitions.each do |transition|
      tag("button", { :class => "transition", :name => transition.name,
                      :formaction => "?transition=#{transition.name}" }, :"#{transition.name}_button") do
        text transition.name.to_s.humanize
      end
    end
  end
end

# --- who is using the application -------------------------------------------
#
# The right-hand side of the navigation bar. It is here and not in the theme for
# the reason piece 13a gives: *that* there is a way to log out is something an
# application has; how it looks is the theme's business.

module HoboRapid
  module Tags

    module SessionSupport

      # Nobody, said properly. Hobo's own `current_user` never answers nil: it
      # answers a `Guest`, which is a real object that says no to everything --
      # and which has no `id` and no page. So "is there somebody here?" is not
      # `current_user`, it is this.
      def someone_here
        user = current_user
        return nil if user.nil?
        return nil if user.respond_to?(:guest?) && user.guest?
        user
      end

      # What to call the person on screen. The model already knows: it is the
      # field they log in with, or their name if they have one.
      def user_label(user)
        return nil if user.nil?
        %w[name login email_address email].each do |field|
          value = user.send(field) if user.respond_to?(field)
          return value.to_s if value.present?
        end
        user.to_s
      end

      # A named route, or nil when there is no application or no such route.
      # A tag that assumes a route exists is a tag that cannot be tested on its
      # own, and one that explodes in an application that removed it.
      def route_path(name)
        return nil unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        Rails.application.routes.url_helpers.send(name)
      rescue StandardError
        nil
      end

      # Development and test only, and gated again in the controller. A way to
      # become somebody else is a developer's tool, and it must be impossible to
      # switch on by accident anywhere else.
      def developer_features?
        return false unless defined?(Rails) && Rails.respond_to?(:env) && Rails.env
        return false unless Rails.env.development? || Rails.env.test?
        config = Rails.application.config.hobo rescue nil
        config.nil? || config.developer_features
      rescue StandardError
        false
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::SessionSupport)

# Log in, or who you are and how to stop being them.
#
# Rails owns the session (piece 15), so these are Rails' own routes: a log out
# is a DELETE, which is why it is a form and not a link -- a link that logs you
# out gets followed by every crawler and prefetcher there is.
Rapid.define(:session_links) do
  user = someone_here
  new_session = route_path(:new_session_path)
  session = route_path(:session_path)

  if user
    tag("li", { :class => "nav-item" }, :logged_in_as) do
      # `path_for` belongs to the derivation engine; the structural tags must
      # work without it, so they ask before using it.
      path = respond_to?(:path_for) ? path_for(user) : nil
      label = t(:"session.logged_in_as", "Logged in as %{name}", :name => user_label(user))
      if path
        tag("a", { :class => "nav-link", :href => path }, :link) { text label }
      else
        tag("span", { :class => "nav-link" }, :label) { text label }
      end
    end

    if session
      tag("li", { :class => "nav-item" }, :log_out) do
        tag("form", { :method => "post", :action => session, :class => "d-inline" }, :form) do
          param(:authenticity_token) { authenticity_token_field }
          tag("input", { :type => "hidden", :name => "_method", :value => "delete" })
          tag("button", { :type => "submit", :class => "btn btn-link nav-link" }, :button) { text t(:"session.log_out", "Log out") }
        end
      end
    end
  elsif new_session
    tag("li", { :class => "nav-item" }, :log_in) do
      tag("a", { :class => "nav-link", :href => new_session }, :link) { text t(:"session.log_in", "Log in") }
    end
  end
end

# The user changer: become somebody else without logging out and in again.
#
# It is the tool that made Hobo's permissions worth having -- you write
# `view_permitted?` and then you *look*, as each person, in one click. Testing
# permissions by logging in and out is testing them once and never again.
#
# It is a GET form with a select that submits itself, so there is no inline
# JavaScript and no exception to make in the content security policy. The
# controller checks the environment again: the route not existing is the first
# lock, and it is not the only one.
Rapid.define(:dev_user_changer, :attrs => [:limit]) do
  next unless developer_features?

  # `user_model` and `login_field` come with the front page tags; without them
  # loaded there is nobody to offer.
  next unless respond_to?(:user_model) && respond_to?(:login_field)

  model = user_model
  action = route_path(:hobo_dev_user_path)
  next if model.nil? || action.nil?

  field = login_field
  people = begin
             model.limit(attributes[:limit] || 30).to_a
           rescue StandardError
             []
           end
  next if people.empty?

  current = someone_here

  tag("form", { :method => "get", :action => action, :class => "dev-user-changer d-inline" }, :form) do
    tag("select", { :name => field, :class => "form-select form-select-sm",
                    :"aria-label" => t(:"session.change_user", "Change user"),
                    :"data-controller" => "rapid-autosubmit",
                    :"data-action" => "change->rapid-autosubmit#submit" }, :select) do
      tag("option", { :value => "" }) { text t(:"session.guest", "Guest") }
      people.each do |person|
        value = person.send(field).to_s
        selected = { :selected => true } if current && current.id == person.id
        tag("option", { :value => value }.merge(selected || {})) { text user_label(person) }
      end
    end
  end
end
