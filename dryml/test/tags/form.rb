# Spike D -- <form>, the second big tag, ported to the Ruby DSL.
#
# It was picked because it is nothing like <table-plus>. <form> is really *two*
# tags:
#
#   - the base <form> (hobo_rapid/taglibs/forms/form.dryml): polymorphic, ten
#     lines of markup, no params at all, and all of its work in a Ruby helper
#     (form_helper, hobo_rapid/app/helpers/hobo_rapid_helper.rb:106)
#   - the per-model <form for="Story">, which Hobo generates into
#     app/views/taglibs/auto/rapid/forms.dryml from
#     hobo/lib/hobo/rapid/generators/rapid/forms.dryml.erb -- and *that* is
#     where the params live: error-messages, field-list, actions, submit, cancel
#
# So it exercises what <table-plus> did not: polymorphic dispatch on the model,
# `merge` on a tag call, a call exposed as `param="default"`, and params that
# live one and two tag calls deeper than the tag the caller names.
#
#   ruby spike/dryml/d_form.rb
#
# Stubbed, because they are Rails and not the tag runtime: routing (object_url),
# forgery protection, i18n, and the model's permission methods.

# Runnable on its own, so it sets the load path up the way the Rakefile does.
$LOAD_PATH.unshift File.expand_path("../../../hobo_support/lib", __dir__)

require "cgi"
require_relative "../../lib/rapid"
require_relative "rapid_helpers"

module FormSpike

  # Stands in for a Hobo model: only what <form> actually asks of it.
  class Story
    attr_accessor :title, :status
    attr_reader :id, :errors

    def initialize(id: nil, title: "", status: "draft", editable: true, creatable: true, errors: [])
      @id, @title, @status = id, title, status
      @editable, @creatable, @errors = editable, creatable, errors
    end

    def new_record? = @id.nil?
    def creatable_by?(_user) = @creatable
    def editable_by?(_user) = @editable
    def to_param = @id.to_s

    def self.name_attribute = :title
    def self.human_attribute_name(name) = name.to_s.capitalize

    # Routing is stubbed, so the model says where its collection lives.
    def self.collection_path = "/stories"
    def self.param_prefix = "story"
  end

  # The port of form_helper. In Hobo this is a view helper, and it stays one
  # here: it is Ruby that happens to be called from a tag, not markup.
  module Helper

    FORM_ATTRS = [:action, :method, :web_method, :lifecycle, :multipart, :hidden_fields].freeze

    # Returns the pieces the <form> element needs, or **nil** when the form must
    # not be rendered at all -- no action could be worked out, or the user has
    # no permission. That is what makes <form> disappear and leaves DRYML's
    # `<else>` to take over.
    def form_helper(attributes)
      attrs, other_attrs = attributes.partition_hash(FORM_ATTRS)
      ajax_attrs, html_attrs = other_attrs.partition_hash(RapidHelpers::AJAX_ATTRS)

      new_record = this.try(:new_record?)
      method = attrs[:method]&.downcase ||
               ((attrs[:action] || attrs[:web_method] || new_record) ? "post" : "put")
      action = attrs[:action] || object_url(this, attrs[:web_method] || attrs[:lifecycle])

      return nil unless action
      return nil if attrs[:action].nil? && !form_permitted?(attrs, new_record)

      form_attrs = { :action => action }
      form_attrs[:enctype] = "multipart/form-data" if attrs[:multipart]

      hiddens = []
      if method == "put" || method == "delete"
        # Browsers do not do PUT: post, and let Rails read the _method field.
        hiddens << hidden_field("_method", method.upcase)
        form_attrs[:method] = "post"
      else
        form_attrs[:method] = method
      end

      unless method == "get"
        hiddens << hidden_field("page_path", page_path)
        hiddens << hidden_field("authenticity_token", authenticity_token)
      end

      # The automatic css classes, only when the action was not given by hand.
      if attrs[:action].nil?
        classes = if attrs[:web_method]
                    "#{type_id}-#{attrs[:web_method]}-form"
                  else
                    "#{'new ' if new_record}#{type_id}"
                  end
        html_attrs = merge_attributes(html_attrs, :class => classes)
      end

      [html_attrs, form_attrs, ajax_attrs, hiddens]
    end

    private

    def form_permitted?(attrs, new_record)
      return true if attrs[:lifecycle]
      new_record ? this.creatable_by?(current_user) : this.editable_by?(current_user)
    end

    def type_id = this.class.name.split("::").last.downcase

    def hidden_field(name, value)
      %(<input type="hidden" name="#{name}" value="#{CGI.escapeHTML(value.to_s)}">)
    end

    # --- what Rails would provide --------------------------------------------

    def current_user = nil
    def page_path = "/stories"
    def authenticity_token = "TOKEN"

    def object_url(record, action = nil)
      return nil unless record.respond_to?(:new_record?)
      collection = record.class.collection_path
      url = record.new_record? ? collection : "#{collection}/#{record.to_param}"
      action ? "#{url}/#{action}" : url
    end

  end

end

Rapid::Tag.include(FormSpike::Helper)


# --- the tags <form> leans on ------------------------------------------------

Rapid.define(:error_messages) do
  messages = this.try(:errors) || []
  next if messages.empty?
  tag("div", { :class => "error-messages" }) do
    tag("ul") { messages.each { |message| tag("li") { text message } } }
  end
end

Rapid.define(:submit, :attrs => [:label]) do
  tag("input", { :type => "submit", :value => attributes[:label] || "Save" })
end

Rapid.define(:or_cancel, :attrs => [:label]) do
  raw " or "
  tag("a", { :href => "#", :class => "cancel" }) { text attributes[:label] || "Cancel" }
end

Rapid.define(:input, :attrs => [:name]) do
  field = attributes[:name]
  tag("input", { :type => "text",
                 :name => "#{this.class.param_prefix}[#{field}]",
                 :value => this.send(field) })
end

# A reduced <field-list>. The real one is <feckless-fieldset>
# (hobo_rapid/taglibs/lists/feckless_fieldset.dryml); what matters here is that
# it declares a param per field with a *computed* name, so the params a caller
# has to reach live one tag call deeper than the <form> they name.
Rapid.define(:field_list, :attrs => [:fields]) do
  tag("fieldset", { :class => "field-list" }, :fieldset) do
    tag("legend", {}, :legend) if all_parameters[:legend]

    comma_split(attributes[:fields]).each do |field|
      with_scope(:field_name => field) do
        tag("div", { :class => "field" }, :"#{field}_field") do
          tag("label", {}, :"#{field}_label") { text this.class.human_attribute_name(field) }
          param(:"#{field}_view") { call_tag(:input, { :name => field }, :as => :"#{field}_tag") }
        end
      end
    end
  end
end


# --- the port: the base <form> ------------------------------------------------
#
# <def tag="form" polymorphic attrs="before-unload">

Rapid.define(:form, :attrs => FormSpike::Helper::FORM_ATTRS + [:before_unload]) do
  pieces = form_helper(attributes)

  # `unless body.nil?` in the original: no permission, no form, no complaint.
  next unless pieces
  html_attrs, form_attrs, ajax_attrs, hiddens = pieces

  html_attrs = html_attrs.merge(:"data-rapid-form" => ajax_attrs.keys.join(",")) unless ajax_attrs.empty?
  html_attrs = html_attrs.merge(:"data-rapid-before-unload" => attributes[:before_unload]) if attributes[:before_unload]

  tag("form", html_attrs.merge(form_attrs)) do
    tag("div", { :class => "hidden-fields" }) { raw hiddens.join }
    param(:default)
  end
end


# --- the port: the generated <form for="Story"> -------------------------------
#
# <def tag="form" for="Story">
#   <form merge param="default">
#     <error-messages param/>
#     <field-list fields="title, status" param/>
#     <div param="actions">
#       <submit label="Save" param/><or-cancel param="cancel"/>
#     </div>
#   </form>
# </def>

Rapid.define_for(:form, FormSpike::Story) do
  call_tag(:form, attributes, :as => :default, :merge_params => true) do
    call_tag(:error_messages, {}, :as => :error_messages)
    call_tag(:field_list, { :fields => "title, status" }, :as => :field_list)
    tag("div", { :class => "actions" }, :actions) do
      call_tag(:submit, { :label => "Save" }, :as => :submit)
      call_tag(:or_cancel, {}, :as => :cancel)
    end
  end
end


# --- rendering it ------------------------------------------------------------

if __FILE__ == $PROGRAM_NAME
  new_story = FormSpike::Story.new(:title => "")
  saved_story = FormSpike::Story.new(:id => 1, :title => "First", :status => "draft")

  puts "--- a new record: POST to create ---"
  puts Rapid.render(:form, {}, :this => new_story)

  puts
  puts "--- a saved record: PUT, done as POST with the _method field ---"
  puts Rapid.render(:form, {}, :this => saved_story)

  puts
  puts "--- no permission to edit: no form at all ---"
  denied = FormSpike::Story.new(:id => 2, :title => "Locked", :editable => false)
  puts Rapid.render(:form, {}, :this => denied).inspect

  puts
  puts "--- the submit button relabelled, two params deep ---"
  puts Rapid.render(:form, {}, :this => new_story,
                    :submit => Rapid.parameter(:replace => true) do
                      tag("button", { :class => "primary" }) { text "Publish" }
                    end)

  puts
  puts "--- a field's input reached by nesting through <field-list> ---"
  puts Rapid.render(:form, {}, :this => new_story,
                    :field_list => Rapid.parameter(
                      :params => { :title_view => Rapid.markup { tag("textarea") { text this.title } } }))
end
