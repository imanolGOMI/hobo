# The inputs that talk to associations.
#
# These are the ones that have to ask the database what the options are, and
# they are where "a form builds itself" stops being a slogan: `<input:author/>`
# on a belongs_to becomes a select of the authors this user is allowed to see.

require "rapid"
require "hobo_rapid/tags/inputs"
require "hobo_rapid/derivation"

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

    class << self

      # What a row of an <input-many> is made of: the member's own fields, minus
      # the way back to its owner. `MovieGenre` belongs to a movie and to a
      # genre; inside the movie's form only the genre is a question, and asking
      # again which movie it is would be asking the user to repeat the page
      # they are on.
      def fields_of_member(member_class, owner_class)
        return [] unless member_class
        fields = HoboRapid::Derivation.summary_fields(member_class)
        back = back_reference(member_class, owner_class)
        back ? fields - [back] : fields
      end

      def back_reference(member_class, owner_class)
        return nil unless owner_class && member_class.respond_to?(:reflections)
        reflection = member_class.reflections.values.find do |r|
          r.macro == :belongs_to && !r.options[:polymorphic] && r.klass == owner_class
        end
        reflection&.name&.to_s
      rescue StandardError
        nil
      end

      # `movie[movie_genres][0][genre_id]`. A belongs_to is sent as its foreign
      # key -- the row names the record it points at, not the record itself.
      def member_field_name(prefix, index, member_class, field)
        column = foreign_key_for(member_class, field) || field
        "#{prefix}[#{index}][#{column}]"
      end

      def foreign_key_for(member_class, field)
        return nil unless member_class.respond_to?(:reflections)
        reflection = member_class.reflections[field.to_s]
        return nil unless reflection && reflection.macro == :belongs_to
        reflection.foreign_key.to_s
      rescue StandardError
        nil
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

# `<input-many>`: a collection you can grow and shrink inside the form of its
# owner. It is the signature interactive tag of Hobo -- creating a genre from
# inside the film, without leaving the page -- and it is two halves that have to
# agree on a DOM:
#
#   - this tag, which paints the rows and, crucially, **one hidden template
#     row** at index -1;
#   - `rapid_input_many_controller.js`, which clones that template on "add",
#     renumbers everything from zero after any change, and enables or disables
#     what gets submitted.
#
# The names are Hobo's, not Rails': `movie[movie_genres][0][genre_id]`, without
# `_attributes`. That is what `:accessible => true` reads (see
# `Hobo::Model::AccessibleAssociations`), and it is what lets a row name a
# record that does not exist yet.
Rapid.define(:input_many, :attrs => [:minimum, :prefix, :fields, :add_label, :remove_label]) do
  reflection = this_reflection
  owner = this_parent
  prefix = attributes[:prefix] ||
           (owner && this_field ? "#{owner.class.name.demodulize.underscore}[#{this_field}]" : nil)
  members = Array(this)
  member_class = reflection.respond_to?(:klass) && reflection.klass || members.first&.class
  fields = attributes[:fields] || HoboRapid::Tags.fields_of_member(member_class, owner&.class)
  minimum = attributes[:minimum].to_i

  # The row a new one is cloned from. It is painted from a blank record, so an
  # empty collection still gives the user something to add -- an <input-many>
  # that only works once there is already a row is an <input-many> that never
  # starts.
  blank = begin
            member_class&.new
          rescue StandardError
            nil
          end

  row = lambda do |record, index, target|
    attrs = { :class => "input-many-item", :"data-rapid-input-many-target" => target }
    attrs[:hidden] = true if target == "template"

    tag("div", attrs, :"item_#{index}") do
      # The id of an existing record travels with its row, or the server cannot
      # tell "change this one" from "make another".
      if record.respond_to?(:id) && record.id
        tag("input", { :type => "hidden", :name => "#{prefix}[#{index}][id]", :value => record.id.to_s })
      end

      fields.each do |field|
        with_field(field, record) do
          # Named, like every other call the catalogue makes: a theme has to be
          # able to reach inside a row, and the param sweep of layer 3 is what
          # said so -- it failed the moment this call went out unexposed.
          call_tag(:input, { :name => HoboRapid::Tags.member_field_name(prefix, index, member_class, field) },
                   :as => :"#{field}_input")
        end
      end

      tag("button", { :type => "button", :class => "add-item",
                      :"data-action" => "rapid-input-many#add" }, :add) do
        text(attributes[:add_label] || "+")
      end
      tag("button", { :type => "button", :class => "remove-item",
                      :"data-action" => "rapid-input-many#remove" }, :remove) do
        text(attributes[:remove_label] || "−")
      end
    end
  end

  tag("div", { :class => "input-many",
               :"data-controller" => "rapid-input-many",
               :"data-rapid-input-many-prefix-value" => prefix,
               :"data-rapid-input-many-minimum-value" => minimum }, :input_many) do
    row.call(blank, -1, "template") if blank

    members.each_with_index { |member, index| row.call(member, index, "item") }

    # Removing the last row has to *say* so. Without this the parameters simply
    # lack the key, which reads as "leave the collection alone", and the rows
    # the user deleted come back on the next page. The controller enables it
    # only while there are none.
    tag("div", { :"data-rapid-input-many-target" => "empty", :hidden => true }, :empty) do
      tag("input", { :type => "hidden", :class => "empty-input", :name => prefix, :value => "" })
    end
  end
end
