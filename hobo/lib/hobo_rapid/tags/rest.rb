# The rest of the catalogue. Ported from Hobo 2 (2026-08-11).
#
# What was left after the pages, the forms, the collections and the html tags:
# the labelled rows, the name of a thing, the previews, and the inputs that
# `<input>` does not cover on its own.
#
# ## What did not come, and why
#
# Roughly thirty of Hobo 2's tags are not here and are not coming:
#
#   click-editor live-editor live-search editor hot-input   the ajax of 2008;
#                                                           it is Turbo now
#   hobo-cache nested-cache swept-cache                     decided out 2026-08-07
#   login-page login-form account-page not-found-page       Rails 8 does auth
#   forgot-password-page permission-denied-page
#   model-name-human human-attribute-name a-or-an           `t` does it
#   comma-list human-collection-name type-name
#   datepicker-rails                                        belongs in hobo_jquery_ui
#
# Each one has somewhere else to be. A catalogue that keeps a tag because it
# used to exist is a catalogue that grows and never shrinks.

require "rapid"
require "hobo_rapid/tags/structure"

# --- a row with a label ---------------------------------------------------------
#
# The three of them are one element each. They look like nothing and they are
# what `<field-list>` is made of: a page that lays out its own rows writes these
# rather than `<tr>` and `<th>`, so a theme can dress them.

Rapid.define(:labelled_item) { tag("tr", all_attributes, :item) { param(:default) } }
Rapid.define(:item_label) { tag("th", all_attributes, :label) { param(:default) } }
Rapid.define(:item_value) { tag("td", all_attributes, :value) { param(:default) } }

Rapid.define(:labelled_item_list) do
  tag("table", all_attributes.merge("class" => ["labelled-item-list", all_attributes["class"]].compact.join(" "))) do
    param(:default)
  end
end

# `<feckless-fieldset>`: a fieldset with a legend, which is what a form uses to
# put a name over a run of fields. The name is Hobo 2's and it is kept: an
# application coming from it writes exactly this.
Rapid.define(:feckless_fieldset, :attrs => [:legend]) do
  tag("fieldset", all_attributes.except(:legend, "legend"), :fieldset) do
    tag("legend", {}, :legend) { text attributes[:legend].to_s } if attributes[:legend]
    param(:default)
  end
end

# --- what a thing is called -----------------------------------------------------

# `<name>`: the name of whatever is being painted, whatever it is.
#
# A record answers with its name attribute, a collection with how many there
# are, and nothing with a dash. It is the tag a template writes when it does not
# know which of the three it has -- which is most of the time, inside another
# tag.
Rapid.define(:name, :attrs => [:if_present]) do
  if this.nil?
    call_tag(:nil_view) unless attributes[:if_present]
  elsif this.is_a?(Array) || this.respond_to?(:to_ary)
    call_tag(:count)
  else
    call_tag(:name_view)
  end
end

# `<collection-name>`: what a collection of records is called -- "Capítulos" --
# taken from the association it came from, and from the model when there is no
# association.
Rapid.define(:collection_name, :attrs => [:singular, :lowercase]) do
  from = this.respond_to?(:origin_attribute) ? this.origin_attribute : nil
  model = this.respond_to?(:klass) ? this.klass : Array(this).first&.class

  name = if from
           from.to_s.titleize
         elsif model
           attributes[:singular] ? HoboRapid::Derivation.title_of(model) : HoboRapid::Derivation.plural_of(model)
         else
           ""
         end

  name = name.singularize if attributes[:singular] && from
  text(attributes[:lowercase] ? name.downcase : name)
end

# --- the first few, and a link to the rest --------------------------------------

# `<collection-preview>`: what a page shows of a collection it is not the page
# for -- the first few cards and a link to all of them.
Rapid.define(:collection_preview, :attrs => [:limit, :name]) do
  records = Array(this)
  limit = (attributes[:limit] || 3).to_i
  model = this.respond_to?(:klass) ? this.klass : records.first&.class

  tag("div", { "class" => "collection-preview" }, :preview) do
    call_tag(:collection, {}, :as => :collection, :this => records.first(limit))

    if records.length > limit && model
      target = path_for(model)
      next if target.nil?

      tag("a", { "href" => target, "class" => "more" }, :more) do
        text t(:"index.see_all", "See all %{count}", :count => records.length)
      end
    end
  end
end

# The name Hobo 2 gave the same thing. Kept because templates write it.
Rapid.define(:preview_with_more, :attrs => [:limit]) { call_tag(:collection_preview, all_attributes) }

# `<links-for-collection>`: the records as a run of links, with commas. What a
# card writes when a collection is one line of a summary rather than a section.
Rapid.define(:links_for_collection) do
  records = Array(this).select { |record| viewable?(record) }

  tag("span", { "class" => "links-for-collection" }, :links) do
    records.each_with_index do |record, index|
      raw(", ") if index.positive?
      with_this(record) { call_tag(:a, {}, :as => :link) }
    end
  end
end

# --- the inputs that `<input>` does not cover -----------------------------------

# `<select-menu>`: a `<select>` built from a list of options given by hand, for
# a field that is not an association -- a status, a size.
Rapid.define(:select_menu, :attrs => [:options, :include_blank, :name]) do
  options = Array(attributes[:options])
  field = this_field
  name = attributes[:name] || (this_parent && field ? "#{this_parent.class.name.underscore}[#{field}]" : nil)

  tag("select", all_attributes.except(:options, "options", :include_blank, "include_blank").merge("name" => name.to_s), :select) do
    tag("option", { "value" => "" }) { text "" } if attributes[:include_blank]

    options.each do |option|
      label, value = option.is_a?(Array) ? option : [option.to_s, option.to_s]
      chosen = value.to_s == this.to_s ? { "selected" => true } : {}
      tag("option", { "value" => value.to_s }.merge(chosen)) { text label.to_s }
    end
  end
end

# `<select-input>` is what Hobo 2 called it when the options come from the
# field's own type -- an enum. Same element, other source.
Rapid.define(:select_input, :attrs => [:options, :include_blank]) do
  options = attributes[:options]
  options ||= this_parent&.class&.try(:attr_type, this_field).try(:values) if this_field
  call_tag(:select_menu, all_attributes.merge(:options => Array(options)))
end

# `<select-many>`: a `<select multiple>` for a has_many. The plain-html half of
# `<check-many>`, which is what the derived forms use.
Rapid.define(:select_many, :attrs => [:options]) do
  reflection = this_field_reflection if respond_to?(:this_field_reflection)
  choices = attributes[:options]
  choices ||= reflection&.klass&.all&.select { |record| viewable?(record) }
  chosen = Array(this).map { |record| record.respond_to?(:id) ? record.id : record }

  name = this_parent && this_field ? "#{this_parent.class.name.underscore}[#{this_field.to_s.singularize}_ids][]" : nil

  tag("select", { "name" => name.to_s, "multiple" => true, "class" => "select-many" }, :select) do
    Array(choices).each do |choice|
      value = choice.respond_to?(:id) ? choice.id : choice
      selected = chosen.include?(value) ? { "selected" => true } : {}
      tag("option", { "value" => value.to_s }.merge(selected)) do
        with_this(choice) { call_tag(:name_view) }
      end
    end
  end
end

# `<input-all>`: an input for every field of the record, which is the shortest
# form a page can ask for.
Rapid.define(:input_all) { call_tag(:field_list, { :mode => "input" }, :as => :fields) }

# `<hidden-id-field>`: what a nested form carries so the server knows which
# record each block of fields belongs to.
Rapid.define(:hidden_id_field) do
  next if this.nil? || !this.respond_to?(:id) || this.id.nil?
  prefix = this_parent && this_field ? "#{this_parent.class.name.underscore}[#{this_field}]" : this.class.name.underscore
  tag("input", { :type => "hidden", :name => "#{prefix}[id]", :value => this.id.to_s })
end

# --- and one that talks to somebody else ----------------------------------------

# `<gravatar>`: the picture of an email address, from gravatar.com.
#
# It stays because applications write it and it is four lines. Worth knowing
# what it does: it sends a hash of the address to a third party on every page
# view, which was unremarkable in 2010 and is a decision now.
Rapid.define(:gravatar, :attrs => [:email, :size, :default]) do
  require "digest/md5"
  address = (attributes[:email] || this).to_s.strip.downcase
  next if address.empty?

  size = (attributes[:size] || 50).to_i
  query = { "s" => size, "d" => (attributes[:default] || "mm") }.to_query

  tag("img", { "src" => "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(address)}?#{query}",
               "class" => "gravatar", "width" => size, "height" => size, "alt" => "" })
end

# --- the pages Hobo 2 named separately -------------------------------------------
#
# `new-page` and `edit-page` are `form_page`: one form, and what changes between
# them is whether the record is saved, which the record already knows. They are
# kept as names because templates write them.

Rapid.define(:new_page) { call_tag(:form_page, all_attributes, :as => :page) }
Rapid.define(:edit_page) { call_tag(:form_page, all_attributes, :as => :page) }

# `<after-submit>`: where a form says what to do once it is sent. In Hobo 2 it
# was ajax; with Turbo it is the response that decides, so this carries the
# `data-turbo-action` and nothing else.
Rapid.define(:after_submit, :attrs => [:go_to]) do
  tag("input", { :type => "hidden", :name => "after_submit", :value => attributes[:go_to].to_s })
end
