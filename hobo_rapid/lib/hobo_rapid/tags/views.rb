# <view>: how a value is painted, decided by its type.
#
# This is the heart of piece 9. `<view:body/>` does not say how to paint the
# body -- it says "paint this field", and the type decides. A `:markdown` field
# comes out as html, a `:date` as a formatted date, a boolean as a tick.
#
# The dispatch is the runtime's (Rapid.define_for), and it goes on the field's
# **declared** type, so a blank field still paints as the kind of thing it is.

require "rapid"

module HoboRapid

  # Raised instead of naming Hobo::PermissionDeniedError, so the catalogue can
  # be loaded and tested without the whole of Hobo.
  class PermissionDenied < RuntimeError; end

  module Tags

    # Everything <view> needs to know about the field it is painting, kept in
    # one place because these questions always travel together.
    module ViewSupport

      # `story.title` -> "story-title", which is what a stylesheet hangs off.
      def type_and_field
        return nil unless this_parent && this_field
        "#{this_parent.class.name.demodulize}-#{this_field}".underscore.dasherize
      end

      def can_view?
        return true unless this_parent && this_field
        return true unless this_parent.respond_to?(:viewable_by?)
        this_parent.viewable_by?(acting_user, this_field)
      end

      # Stands in for the controller's current_user until the derivation engine
      # wires it through.
      def acting_user = nil

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::ViewSupport)

# `<view>` and the type views are **two** tags, not one, and that is not an
# accident: a polymorphic definition *replaces* the whole tag, so if the type
# views were `<view>` itself they would lose the permission check, the wrapper
# and the blank handling. So `<view>` keeps all of that and delegates the paint
# to `<view-content>`, which is the polymorphic one. DRYML had the same pair.
Rapid.define(:view, :attrs => [:if_blank, :inline, :block, :no_wrapper, :truncate, :force, :html]) do
  unless attributes[:force] || can_view?
    raise HoboRapid::PermissionDenied, "no se puede ver el campo '#{this_field}'"
  end

  # A blank value never reaches the type view -- there is nothing to paint and
  # `nil` does not answer to what a type view would ask of it. The wrapper is
  # still painted, so the page does not jump about when a value appears.
  painted = this.nil? ? "" : capture { param(:default) { call_tag(:view_content) } }

  painted = attributes[:if_blank].to_s if painted.blank? && attributes[:if_blank]
  painted = painted.to_s[0, attributes[:truncate].to_i] if attributes[:truncate]

  if attributes[:no_wrapper]
    raw painted
  else
    wrapper = attributes[:block] ? "div" : "span"
    classes = ["view", type_and_field].compact.join(" ")
    tag(wrapper, { :class => classes }.merge(attributes[:html] || {})) { raw painted }
  end
end

# The paint itself, decided by the type.
Rapid.define(:view_content) { text this.to_s }

Rapid.define_for(:view_content, Date)    { text this.strftime("%Y-%m-%d") }
Rapid.define_for(:view_content, Time)    { text this.strftime("%Y-%m-%d %H:%M") }
Rapid.define_for(:view_content, Numeric) { text this.to_s }
Rapid.define_for(:view_content, Rapid::Boolean) { raw(this ? "&#10004;" : "&#10008;") }
