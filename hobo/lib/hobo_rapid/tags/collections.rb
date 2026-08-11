# Collections, pagination and buttons. Ported from Hobo 2 (2026-08-11).
#
# What a list of records looks like when you are not painting a table: a run of
# cards, a message when there is nothing, a way to walk the pages, and the
# buttons that act on one record.
#
# The derived pages paint a table, which is the right default for an index. This
# is what an application writes when it wants the other shape:
#
#   <%= hobo.collection %>
#   <%= hobo.page_nav %>

require "rapid"
require "hobo_rapid/tags/structure"

# `<collection>`: the records, each one as a card.
#
# `<ul>` by default because a list of things is a list -- Hobo 2 chose that and
# it is right -- and any other element with `list_tag`.
Rapid.define(:collection, :attrs => [:list_tag]) do
  records = Array(this).select { |record| viewable?(record) }

  if records.empty?
    call_tag(:empty_collection_message, {}, :as => :empty_message)
    next
  end

  element = (attributes[:list_tag] || "ul").to_s
  classes = ["collection", all_attributes["class"]].compact.join(" ")

  tag(element, all_attributes.except(:list_tag, "list_tag").merge("class" => classes)) do
    records.each_with_index do |record, index|
      with_this(record) do
        tag("li", { "class" => index.even? ? "even" : "odd" }, :item) do
          param(:default) { call_tag(:card, {}, :as => :card) }
        end
      end
    end
  end
end

# What a list says when there is nothing in it.
#
# A page that goes blank where a list should be is a page that looks broken.
# This is the difference between "there is nothing yet" and "something went
# wrong", and only the application knows which -- so it is a param.
Rapid.define(:empty_collection_message) do
  tag("p", { "class" => "empty-collection" }, :message) do
    param(:default) { text t(:"index.empty", "Nothing here yet.") }
  end
end

# `<count>`: how many, said in words rather than as a number on its own.
Rapid.define(:count, :attrs => [:label]) do
  many = Array(this).length
  name = attributes[:label].to_s

  tag("span", { "class" => "count" }, :count) do
    text(name.empty? ? many.to_s : t(:"index.count", "%{count} %{name}", :count => many, :name => name))
  end
end

# `<page-nav>`: the pages of a paginated list.
#
# Hobo 2 handed this to will_paginate's view helper. The tag runtime is not a
# view, so the links are built here from what the collection knows -- which also
# means a page painted outside Rails still gets them.
Rapid.define(:page_nav) do
  next unless this.respond_to?(:total_pages) && this.total_pages.to_i > 1

  current = this.current_page.to_i
  query = HoboRapid.query_parameters

  tag("nav", { "class" => "page-nav" }, :page_nav) do
    if current > 1
      tag("a", { "href" => "?#{query.merge("page" => current - 1).to_query}", "class" => "previous" }) do
        text t(:"actions.previous", "« Anterior")
      end
    end

    tag("span", { "class" => "pages" }) do
      text t(:"index.page_of", "%{current} de %{total}", :current => current, :total => this.total_pages)
    end

    if current < this.total_pages.to_i
      tag("a", { "href" => "?#{query.merge("page" => current + 1).to_query}", "class" => "next" }) do
        text t(:"actions.next", "Siguiente »")
      end
    end
  end
end

# --- the buttons that act on one record ----------------------------------------
#
# Each one paints nothing when there is no route or no permission, which is the
# rule the whole catalogue follows: a button that leads nowhere is worse than no
# button.

Rapid.define(:delete_button, :attrs => [:label]) do
  next unless destroyable_here?
  target = path_for(this)
  next if target.nil?

  tag("form", { "method" => "post", "action" => target, "class" => "delete-button" }, :form) do
    tag("input", { :type => "hidden", :name => "_method", :value => "delete" })
    param(:authenticity_token) { authenticity_token_field }
    tag("button", { "type" => "submit", "class" => "action delete" }, :button) do
      param(:default) { text(attributes[:label] || t(:"actions.delete", "Delete")) }
    end
  end
end

Rapid.define(:create_button, :attrs => [:label]) do
  model = this.is_a?(Module) ? this : this.class
  target = new_path_for(model)
  next if target.nil? || !creatable_here?(model)

  tag("a", { "href" => target, "class" => "action new" }, :link) do
    param(:default) do
      text(attributes[:label] || t(:"index.new_link", "New %{name}",
                                   :name => HoboRapid::Derivation.title_of(model).downcase))
    end
  end
end

Rapid.define(:update_button, :attrs => [:label]) do
  next unless editable_here?
  target = edit_path_for(this)
  next if target.nil?

  tag("a", { "href" => target, "class" => "action edit" }, :link) do
    param(:default) { text(attributes[:label] || t(:"actions.edit", "Edit")) }
  end
end

# `<transition-link>`: one lifecycle transition, as a link.
#
# `<transition-buttons>` already paints all of them; this is the one you name
# when a page wants a single transition in a place of its own.
Rapid.define(:transition_link, :attrs => [:transition, :label]) do
  name = attributes[:transition].to_s
  next if name.empty? || !this.respond_to?(:lifecycle)
  next unless this.lifecycle.can_run?(name, HoboRapid.current_user)

  target = path_for(this)
  next if target.nil?

  tag("form", { "method" => "post", "action" => "#{target}/#{name}", "class" => "transition" }, :form) do
    param(:authenticity_token) { authenticity_token_field }
    tag("button", { "type" => "submit", "class" => "action transition #{name}" }, :button) do
      param(:default) { text(attributes[:label] || name.humanize) }
    end
  end
end

# --- odds and ends the old pages write ------------------------------------------

# `<nil-view>`: what a blank field looks like. A page where an empty value
# leaves a hole reads as broken; a dash reads as empty.
Rapid.define(:nil_view) do
  tag("span", { "class" => "nil-view" }, :nil_view) { param(:default) { raw("&mdash;") } }
end

# `<hidden-field>` and `<hidden-fields>`: what a form carries without showing.
Rapid.define(:hidden_field, :attrs => [:name, :value]) do
  tag("input", { :type => "hidden", :name => attributes[:name].to_s, :value => attributes[:value].to_s })
end

Rapid.define(:hidden_fields, :attrs => [:fields]) do
  record = this
  attributes[:fields].to_s.split(",").map(&:strip).reject(&:empty?).each do |field|
    tag("input", { :type => "hidden",
                   :name => "#{record.class.name.underscore}[#{field}]",
                   :value => record.send(field).to_s })
  end
end
