# Piece 10: the derivation engine. *The* reason to use Hobo.
#
# You declare a model with `fields do`, and the pages exist: a card that
# summarises a record, an index that lists them, a page that shows one, a form
# that edits it. Nobody writes those views. The model already said everything
# they need -- which fields it has, what type each one is, which one is its
# name, which are its children -- and this reads it back.
#
# It used to work by **generating DRYML source** into
# app/views/taglibs/auto/rapid/*.dryml from 534 lines of ERB, at boot, on every
# reload. That was the only way to do it when tags were a template language.
#
# With tags as Ruby objects there is nothing to generate: the tags are defined
# by running Ruby. No files written, nothing to gitignore, no boot-time
# codegen, and a mistake shows up as a Ruby error with a stack trace instead of
# as a syntax error in a file nobody wrote.

require "rapid"
require "hobo_rapid/tags/views"
require "hobo_rapid/tags/inputs"
require "hobo_rapid/tags/associations"

module HoboRapid

  # A derived page goes **inside the theme**, so it comes out with the navbar,
  # the container and the stylesheets. Without this the pages painted fine and
  # looked like nothing at all -- which is what happens when you build the theme
  # and never connect it to anything.
  #
  # If no theme is loaded the content is painted on its own, so the engine never
  # depends on there being one.
  module InPage

    def in_page(title, &content)
      if Rapid.tags.key?(:page)
        call_tag(:page, { :title => title }, :as => :page, :content_body => content)
      else
        content.call
      end
    end

  end

  # Where a record lives. The tag runtime is not a Rails view, so it asks Rails
  # when there is one and paints no link when there is not -- a catalogue that
  # cannot be used outside an application would be a catalogue nobody can test.
  module Routing

    def path_for(record_or_model)
      return nil unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
      Rails.application.routes.url_helpers.polymorphic_path(record_or_model)
    rescue StandardError
      nil
    end

  end

  module Derivation

    class << self

      # Everything the engine asks of a model. Written down here on purpose:
      # this is the contract, and anything that answers it can be derived from,
      # which is what makes the engine testable without a database.
      def fields_of(model)
        if model.respond_to?(:field_specs)
          model.field_specs.keys.map(&:to_s)
        elsif model.respond_to?(:column_names)
          model.column_names - %w[id created_at updated_at]
        else
          []
        end
      end

      def name_attribute_of(model)
        return model.name_attribute.to_s if model.respond_to?(:name_attribute) && model.name_attribute
        (fields_of(model) & %w[name title]).first
      end

      def children_of(model)
        return [] unless model.respond_to?(:view_hints)
        Array(model.view_hints.children).map(&:to_s)
      end

      def title_of(model) = model.name.demodulize.underscore.humanize
      def plural_of(model) = title_of(model).pluralize

      # Rails keeps these, and they are never what a page is about.
      HOUSEKEEPING = %w[created_at updated_at id type].freeze

      # The fields a summary shows: everything but the name (which is the
      # heading), the children (collections, not summary material) and the
      # housekeeping columns -- a card that leads with "Created at" is a card
      # about the database, not about the record.
      def summary_fields(model)
        fields_of(model) - [name_attribute_of(model)] - children_of(model) - HOUSEKEEPING
      end

      # Defines <card>, <show-page>, <index-page> and <form> for one model.
      # Called once per model; calling it again redefines, which is what a
      # reload wants.
      def derive(model)
        derive_card(model)
        derive_show_page(model)
        derive_index_page(model)
        derive_form(model)
        derive_form_page(model)
        model
      end

      private

      # A card: the record in a box, small enough to sit in a list.
      def derive_card(model)
        name_attribute = name_attribute_of(model)
        fields = summary_fields(model)

        # What a record is called, on its own, so both the card and the link
        # can use it.
        Rapid.define_for(:name_view, model) do
          if name_attribute
            with_field(name_attribute) { call_tag(:view, { :no_wrapper => true }, :as => :name) }
          else
            param(:name) { text this.to_s }
          end
        end

        Rapid.define_for(:card, model) do
          tag("div", { :class => "card #{model.name.demodulize.underscore}" }, :card) do
            tag("h3", {}, :heading) do
              # A card nobody can click is a list nobody can use. The link is a
              # param of its own so a theme can change it without losing it.
              param(:name) do
                path = path_for(this)
                if path
                  tag("a", { :href => path }, :link) { call_tag(:name_view, {}, :as => :name_view) }
                else
                  call_tag(:name_view, {}, :as => :name_view)
                end
              end
            end
            tag("dl", {}, :body) do
              fields.each do |field|
                with_field(field) do
                  tag("dt", {}, :"#{field}_label") { text HoboRapid::Derivation.label_for(model, field) }
                  tag("dd", {}, :"#{field}_value") { call_tag(:view, {}, :as => :"#{field}_view") }
                end
              end
            end
          end
        end
      end

      # The page for one record: everything it has, plus its children.
      def derive_show_page(model)
        name_attribute = name_attribute_of(model)
        fields = summary_fields(model)
        children = children_of(model)

        Rapid.define_for(:show_page, model) do
          heading = name_attribute ? this.send(name_attribute).to_s : model.name.demodulize
          in_page(heading) do
          tag("article", { :class => "show-page #{model.name.demodulize.underscore}" }, :body) do
            tag("h1", {}, :heading) do
              if name_attribute
                with_field(name_attribute) { call_tag(:view, {}, :as => :name) }
              else
                param(:name) { text this.to_s }
              end
            end

            tag("dl", {}, :fields) do
              fields.each do |field|
                with_field(field) do
                  tag("dt", {}, :"#{field}_label") { text HoboRapid::Derivation.label_for(model, field) }
                  tag("dd", {}, :"#{field}_value") { call_tag(:view, {}, :as => :"#{field}_view") }
                end
              end
            end

            children.each do |child|
              tag("section", { :class => "children #{child}" }, :"#{child}_section") do
                tag("h2", {}, :"#{child}_heading") { text child.humanize }
                # `as:` on the way in, so a theme can reach the collection view
                # and everything inside it. The param contract sweep of layer 3
                # is what insists on this, and it is right to.
                with_field(child) { call_tag(:view, { :force => true }, :as => :"#{child}_collection") }
              end
            end
          end
          end
        end
      end

      # The page for the collection: a card each.
      def derive_index_page(model)
        Rapid.define_for(:index_page, model) do
          in_page(HoboRapid::Derivation.plural_of(model)) do
          tag("div", { :class => "index-page #{model.name.demodulize.underscore.pluralize}" }, :body) do
            tag("h1", {}, :heading) { text HoboRapid::Derivation.plural_of(model) }
            tag("div", { :class => "collection" }, :collection) do
              records = Array(this)
              if records.empty?
                tag("p", { :class => "empty" }, :empty) { text "Nada por aqui todavia." }
              else
                records.each { |record| with_this(record) { call_tag(:card, {}, :as => :card) } }
              end
            end
          end
          end
        end
      end

      # The form: an input per field, which is where `fields do` pays off --
      # the type of each field decides its control.
      def derive_form(model)
        fields = summary_fields(model)
        name_attribute = name_attribute_of(model)
        all = ([name_attribute] + fields).compact

        Rapid.define_for(:model_form, model) do
          tag("div", { :class => "form-fields" }, :fields) do
            all.each do |field|
              with_field(field) do
                tag("div", { :class => "field" }, :"#{field}_field") do
                  tag("label", {}, :"#{field}_label") { text HoboRapid::Derivation.label_for(model, field) }
                  call_tag(:input, {}, :as => :"#{field}_input")
                end
              end
            end
          end
        end
      end

      # The page you get at `new` and `edit`: the form, in the theme, with a
      # button to send it. Deriving the form and never rendering it anywhere was
      # the same mistake as building the theme and not connecting it -- the
      # piece existed and the product did not have it.
      def derive_form_page(model)
        Rapid.define_for(:form_page, model) do
          new_record = this.respond_to?(:new_record?) && this.new_record?
          title = "#{new_record ? 'Nuevo' : 'Editar'} #{model.name.demodulize.underscore.humanize.downcase}"

          in_page(title) do
            tag("div", { :class => "form-page #{model.name.demodulize.underscore}" }, :body) do
              tag("h1", {}, :heading) { text title }

              action = path_for(new_record ? model : this)
              tag("form", { :class => "hobo-form", :method => "post", :action => action }, :form) do
                unless new_record
                  tag("input", { :type => "hidden", :name => "_method", :value => "patch" })
                end
                param(:authenticity_token) { authenticity_token_field }

                call_tag(:error_messages, {}, :as => :errors)
                # Not `:as => :fields`: the form declares a param of that name
                # itself, and the outer one silently replaced it -- the fields
                # came out empty and nothing complained.
                call_tag(:model_form, {}, :as => :form_fields)

                tag("div", { :class => "actions" }, :actions) do
                  tag("button", { :type => "submit", :class => "btn btn-primary" }, :submit) do
                    text(new_record ? "Crear" : "Guardar")
                  end
                end
              end
            end
          end
        end
      end

      public

      def label_for(model, field)
        return model.human_attribute_name(field) if model.respond_to?(:human_attribute_name)
        field.to_s.humanize
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::InPage)
Rapid::Tag.include(HoboRapid::Routing)

# The tags the derived ones fall back to when a model has said nothing.
Rapid.define(:card) { tag("div", { :class => "card" }, :card) { call_tag(:view, :force => true) } }
Rapid.define(:show_page) { tag("article", {}, :page) { call_tag(:view, :force => true) } }
Rapid.define(:index_page) { tag("div", {}, :page) { call_tag(:view, :force => true) } }
Rapid.define(:model_form) { tag("div", {}, :fields) { } }
Rapid.define(:name_view) { text this.to_s }
Rapid.define(:form_page) { tag("div", {}, :page) { call_tag(:model_form) } }
