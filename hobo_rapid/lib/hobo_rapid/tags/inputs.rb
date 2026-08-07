# <input>: how a value is *edited*, decided by its type.
#
# The mirror of <view>, and the same shape: a general <input> that holds the
# permission check, the field name and the wrapper, and a polymorphic
# <input-content> that paints the control. Two tags, for the same reason as
# there -- a polymorphic definition replaces the whole tag.
#
# This is where `fields do` pays off. `contact_address :email_address` gives an
# `<input type="email">` without anybody writing it, because the *type* knows.

require "rapid"
require "hobo_rapid/tags/views"

module HoboRapid
  module Tags

    module InputSupport

      # `story[title]`, which is what Rails reads the parameters back out of.
      def param_name_for_this
        return nil unless this_parent && this_field
        "#{this_parent.class.name.demodulize.underscore}[#{this_field}]"
      end

      # Whether this record may be changed or removed at all -- what decides
      # whether an edit or a delete is offered. Asking the record rather than
      # the markup is the point of piece 4.
      def editable_here?
        return true unless this.respond_to?(:editable_by?)
        this.editable_by?(acting_user)
      end

      def destroyable_here?
        return true unless this.respond_to?(:destroyable_by?)
        this.destroyable_by?(acting_user)
      end

      def can_edit?
        return true unless this_parent && this_field
        return true unless this_parent.respond_to?(:editable_by?)
        this_parent.editable_by?(acting_user, this_field)
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::InputSupport)

# `no_edit` says what to do when the user may not edit this field:
#   :view    paint it read-only (the default -- a form that hides what you
#            cannot change tells you less than one that shows it greyed)
#   :disable paint the control, disabled
#   :skip    paint nothing
#   :ignore  do not even ask
Rapid.define(:input, :attrs => [:no_edit, :name, :type]) do
  no_edit = (attributes[:no_edit] || :view).to_sym
  refused = no_edit != :ignore && !can_edit?

  next call_tag(:view) if refused && no_edit == :view
  next if refused && no_edit == :skip

  html = attributes.except(:no_edit, :type)
  html[:name] ||= param_name_for_this
  html[:disabled] = true if refused && no_edit == :disable

  # An association is not a value with a control: it is a choice among records,
  # and which control it wants is decided by the *shape* of the association, not
  # by a type. That is why this is here and not in <input-content>, which
  # dispatches on the class of the value -- and the class of `movie.category` is
  # Category, which says nothing about there being a Genre to pick as well.
  reflection = this_reflection
  case reflection&.macro
  when :belongs_to
    # `select_one` builds its own name from the reflection -- `movie[category_id]`,
    # the foreign key, not `movie[category]` -- so the guessed one is dropped.
    # A name the *caller* gave is kept, because inside an <input-many> the row
    # knows something the field cannot: which row it is.
    given = attributes[:name] ? { :name => attributes[:name] } : {}

    # `:accessible => true` on the association is the model saying this one may
    # be *created* from here, not only chosen. So the control changes, and it
    # changes because the model said so -- nobody edits a view to get it.
    accessible = reflection.options[:accessible] rescue false
    control = accessible ? :select_one_or_new : :select_one
    next param(:default) { call_tag(control, html.except(:name).merge(given), :as => :select) }
  when :has_many, :has_and_belongs_to_many
    next param(:default) { call_tag(:check_many, html.except(:name), :as => :check_many) }
  end

  param(:default) { call_tag(:input_content, html) }
end

# The control itself, decided by the type. The default is a text field, which is
# what an unknown type deserves.
Rapid.define(:input_content, :attrs => [:name, :disabled]) do
  tag("input", { :type => "text", :value => this.to_s }.merge(attributes))
end

Rapid.define_for(:input_content, HoboFields::Types::Text) do
  tag("textarea", attributes.except(:value)) { text this.to_s }
end if defined?(HoboFields::Types::Text)

# The hidden field is the Rails trick: without it an unticked box sends nothing
# at all, and the model never learns it was unticked.
Rapid.define_for(:input_content, Rapid::Boolean) do
  tag("input", { :type => "hidden", :name => attributes[:name], :value => "0" })
  ticked = { :checked => true } if this
  tag("input", { :type => "checkbox", :value => "1" }.merge(attributes).merge(ticked || {}))
end

# These are the ones HTML5 took over. `input_for_date.dryml` was 81 lines of
# day/month/year selects built with Rails' date_select; browsers have had a real
# date control since 2014, and it knows about locales, keyboards and calendars
# better than any of us will.
Rapid.define_for(:input_content, Date) do
  tag("input", { :type => "date", :value => this&.strftime("%Y-%m-%d") }.merge(attributes))
end

Rapid.define_for(:input_content, Time) do
  tag("input", { :type => "datetime-local", :value => this&.strftime("%Y-%m-%dT%H:%M") }.merge(attributes))
end

Rapid.define_for(:input_content, Integer) do
  tag("input", { :type => "number", :step => 1, :value => this }.merge(attributes))
end

Rapid.define_for(:input_content, Float) do
  tag("input", { :type => "number", :step => "any", :value => this }.merge(attributes))
end

Rapid.define_for(:input_content, BigDecimal) do
  tag("input", { :type => "number", :step => "any", :value => this&.to_s }.merge(attributes))
end
