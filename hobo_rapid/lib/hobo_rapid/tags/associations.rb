# The inputs that talk to associations.
#
# These are the ones that have to ask the database what the options are, and
# they are where "a form builds itself" stops being a slogan: `<input:author/>`
# on a belongs_to becomes a select of the authors this user is allowed to see.

require "rapid"
require "hobo_rapid/tags/inputs"

module HoboRapid
  module Tags

    module AssociationSupport

      # The association behind the field being painted, or nil.
      def this_reflection
        return nil unless this_parent && this_field && this_parent.class.respond_to?(:reflections)
        this_parent.class.reflections[this_field.to_s]
      end

      # The records a user may choose from. Capped, because a select with ten
      # thousand options is not a user interface -- the old code capped at 100
      # too, and it is kept as an attribute so a caller can say otherwise.
      def choices_for(reflection, limit)
        return [] unless reflection
        reflection.klass.limit(limit).select { |record| viewable?(record) }
      end

      def viewable?(record)
        !record.respond_to?(:viewable_by?) || record.viewable_by?(acting_user)
      end

      # What to show for a record in a list of choices.
      def choice_label(record, method = nil)
        return method.to_s.split(".").inject(record) { |value, m| value.send(m) } if method
        return record.name if record.respond_to?(:name)
        record.to_s
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::AssociationSupport)

# A belongs_to: one choice out of many.
Rapid.define(:select_one, :attrs => [:include_none, :blank_message, :options, :sort, :limit, :text_method, :disabled, :name]) do
  unless attributes[:disabled] || can_edit?
    raise HoboRapid::PermissionDenied, "no se puede editar el campo '#{this_field}'"
  end

  reflection = this_reflection
  records = attributes[:options] || choices_for(reflection, attributes[:limit] || 100)
  choices = records.map { |record| [choice_label(record, attributes[:text_method]), record.id.to_s] }
  choices = choices.sort_by(&:first) if attributes[:sort]

  # A blank option appears when asked for, and when nothing is chosen yet: a
  # select with no empty option quietly picks the first record for you.
  if attributes[:include_none] || (this.nil? && attributes[:include_none] != false)
    choices.unshift([attributes[:blank_message] || "", ""])
  end

  chosen = this&.id&.to_s
  name = attributes[:name] || (this_parent && reflection ? "#{this_parent.class.name.demodulize.underscore}[#{reflection.foreign_key}]" : nil)

  tag("select", { :name => name, :class => "input belongs-to" }, :select) do
    choices.each do |label, value|
      selected = { :selected => true } if value == chosen
      tag("option", { :value => value }.merge(selected || {})) { text label }
    end
  end
end

# A has_many: many choices, as tick boxes.
Rapid.define(:check_many, :attrs => [:options, :disabled, :limit, :text_method, :name]) do
  chosen = Array(this).map { |record| record.id.to_s }
  reflection = this_reflection
  records = attributes[:options] || choices_for(reflection, attributes[:limit] || 100)
  name = attributes[:name] || "#{param_name_for_this}[]"

  tag("ul", { :class => "check-many" }, :default) do
    # Without this, unticking everything sends nothing at all and the model
    # never learns the collection was emptied. Same trick as the checkbox.
    tag("input", { :type => "hidden", :name => name, :value => "" })

    records.each do |record|
      with_this(record) do
        tag("li", {}, :item) do
          ticked = { :checked => true } if chosen.include?(record.id.to_s)
          tag("input", { :type => "checkbox", :name => name, :value => record.id.to_s,
                         :disabled => attributes[:disabled] }.merge(ticked || {}))
          tag("label", {}, :label) { text choice_label(record, attributes[:text_method]) }
        end
      end
    end
  end
end
