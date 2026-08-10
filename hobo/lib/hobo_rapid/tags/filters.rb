# The filters of a list: piece 6, as it ended up.
#
# The scopes were delegated to Ransack -- 429 lines of `method_missing`
# conjuring `title_contains` for two live callers -- and this is the other end
# of that decision: the markup that sends `q[title_cont]=blade`, which is
# Ransack's own spelling of the same idea.
#
# **These are not derived, and that is deliberate** (decision 18). The index
# page Hobo 2 derived had no filters either: `<search-filter>` and
# `<filter-menu>` were tags you wrote in your own page when you wanted them. A
# filter is a decision about what this list is for, and a list that grows a
# select for every column is not a decision, it is a pile.
#
# What Hobo does give you is that they *work* with nothing else written: the
# model already says which of its attributes may be searched
# (`Hobo::Model.ransackable_attributes`) and the controller already passes the
# collection through Ransack.

require "rapid"
require "hobo_rapid/translation"
require "hobo_rapid/tags/views"
# A menu over a belongs_to is an association question -- who may be seen, and
# what a record is called in a list -- so the answers come from there.
require "hobo_rapid/tags/associations"
require "hobo_rapid/request"

module HoboRapid
  module Tags

    module FilterSupport

      # Ransack's parameters live under `q`, and everything here is one entry in
      # that hash.
      def search_params
        query = HoboRapid.query_parameters
        value = query[:q] || query["q"]
        value.respond_to?(:to_h) ? value.to_h.transform_keys(&:to_s) : {}
      rescue StandardError
        {}
      end

      def search_value(key) = search_params[key.to_s]

      # What the model of the list is. A collection knows: a Relation answers
      # `klass`, and a plain array answers for its first member.
      def collection_model
        return this.klass if this.respond_to?(:klass)
        first = Array(this).first
        first&.class
      rescue StandardError
        nil
      end

      # Everything else that is in the query string right now, so changing one
      # filter does not throw away the others -- or the search you had typed.
      # `page` is dropped on purpose: a new filter starts at the first page.
      def other_filters(except)
        except = Array(except).map(&:to_s)
        search_params.reject { |key, value| except.include?(key) || value.to_s.empty? }
      end

      def hidden_filters(except)
        other_filters(except).each do |key, value|
          tag("input", { :type => "hidden", :name => "q[#{key}]", :value => value })
        end
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::FilterSupport)

# A box to type in. `fields` says what it looks at; by default the field the
# model calls its name, because that is what a person means when they type into
# a list of things.
#
#   <search-filter fields="title, synopsis"/>   ->  q[title_or_synopsis_cont]
Rapid.define(:search_filter, :attrs => [:fields, :label, :placeholder, :button_label, :clear_label]) do
  model = collection_model
  fields = Array(attributes[:fields]).flat_map { |f| f.to_s.split(/\s*,\s*/) }
  fields = [HoboRapid::Derivation.name_attribute_of(model)].compact if fields.empty? && model
  next if fields.empty?

  key = "#{fields.join('_or_')}_cont"
  value = search_value(key)

  tag("form", { :method => "get", :class => "search-filter" }, :form) do
    hidden_filters(key)

    if attributes[:label]
      tag("label", { :class => "form-label" }, :label) { text attributes[:label] }
    end

    tag("input", { :type => "search", :name => "q[#{key}]", :value => value,
                   :class => "form-control",
                   :placeholder => attributes[:placeholder] || t(:"filters.search", "Search") }, :input)

    tag("button", { :type => "submit", :class => "action filter" }, :submit) do
      text(attributes[:button_label] || t(:"filters.search", "Search"))
    end

    # Only when there is something to clear. A button that does nothing is a
    # button you learn to ignore.
    if value.to_s.present?
      tag("a", { :href => "?#{other_filters(key).map { |k, v| "q[#{k}]=#{CGI.escape(v.to_s)}" }.join('&')}",
                 :class => "action clear" }, :clear) do
        text(attributes[:clear_label] || t(:"filters.clear", "Clear"))
      end
    end
  end
end

# A menu to narrow by. Give it a `belongs_to` and it offers the records; give it
# `param` and `options` and it offers those.
#
#   <filter-menu field="category"/>                     ->  q[category_id_eq]
#   <filter-menu param="year_eq" options="&[1960, 1982]"/>
#
# It submits itself, through the same Stimulus controller as every other menu
# that does: `<filter-menu>` and `hot-input` were the same idea written twice in
# the jQuery days, and layer 5 merged them.
Rapid.define(:filter_menu, :attrs => [:field, :param, :options, :label, :all_label, :limit]) do
  model = collection_model
  reflection = model.reflections[attributes[:field].to_s] if model.respond_to?(:reflections) && attributes[:field]

  key = attributes[:param]&.to_s
  key ||= "#{reflection.foreign_key}_eq" if reflection && reflection.macro == :belongs_to
  next if key.nil?

  choices = attributes[:options]
  if choices.nil? && reflection
    choices = reflection.klass.limit(attributes[:limit] || 100)
                        .select { |record| viewable?(record) }
                        .map { |record| [choice_label(record), record.id.to_s] }
  end
  choices = Array(choices).map { |choice| choice.is_a?(Array) ? choice : [choice.to_s, choice.to_s] }
  next if choices.empty?

  chosen = search_value(key)

  # The controller goes on the **form**, not on the select: its reach is its own
  # element, and the fallback button it has to hide is a sibling of the select,
  # not a child of it.
  tag("form", { :method => "get", :class => "filter-menu",
                **HoboRapid::Behaviour.declare("autosubmit") }, :form) do
    hidden_filters(key)

    if attributes[:label]
      tag("label", { :class => "form-label" }, :label) { text attributes[:label] }
    end

    tag("select", { :name => "q[#{key}]", :class => "form-select",
                    **HoboRapid::Behaviour.action("autosubmit", "submit") }, :select) do
      tag("option", { :value => "" }) { text(attributes[:all_label] || t(:"filters.all", "All")) }
      choices.each do |label, value|
        selected = { :selected => true } if value.to_s == chosen.to_s
        tag("option", { :value => value }.merge(selected || {})) { text label }
      end
    end

    # Without JavaScript the menu still works: the button is there, and the
    # controller takes it away when it connects.
    tag("button", { :type => "submit", :class => "action filter",
                    **HoboRapid::Behaviour.target("autosubmit", "fallback") }, :submit) do
      text t(:"filters.filter", "Filter")
    end
  end
end
