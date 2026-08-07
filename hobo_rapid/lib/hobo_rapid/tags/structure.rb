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
      text(count == 1 ? "1 error impidio guardar #{model}" : "#{count} errores impidieron guardar #{model}")
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
