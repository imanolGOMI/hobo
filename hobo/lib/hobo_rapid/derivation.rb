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
require "hobo_rapid/translation"
require "hobo_rapid/tags/views"
require "hobo_rapid/tags/inputs"
require "hobo_rapid/tags/associations"
require "hobo_rapid/tags/html"
require "hobo_rapid/tags/forms"

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
      return nil unless routes
      routes.polymorphic_path(record_or_model)
    rescue StandardError
      nil
    end

    # `new` and `edit` have their own helpers, and without them a page has no
    # way to offer the actions the controller declares. The old theme painted an
    # edit and a delete on every row and a "New X" above the table; the pages
    # here had **none of it**, which is a list you can look at and not use.
    def new_path_for(model)
      return nil unless routes
      routes.polymorphic_path(model, :action => :new)
    rescue StandardError
      nil
    end

    def edit_path_for(record)
      return nil unless routes
      routes.polymorphic_path(record, :action => :edit)
    rescue StandardError
      nil
    end

    def routes
      return nil unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
      Rails.application.routes.url_helpers
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

      # The field a record is *about*: Hobo 2 painted it above the field list,
      # bigger, because a description is not a row in a table of properties.
      PRIMARY_CONTENT = %w[description body content profile].freeze

      def description_attribute_of(model)
        return model.primary_content_attribute.to_s if model.respond_to?(:primary_content_attribute) && model.primary_content_attribute
        (fields_of(model) & PRIMARY_CONTENT).first
      end

      def children_of(model)
        return [] unless model.respond_to?(:view_hints)
        Array(model.view_hints.children).map(&:to_s)
      end

      # What a model is called, **asking Rails**.
      #
      # This used to be `model.name.humanize` and nothing else, so a page said
      # "Stories" whatever language the application was in: the labels of the
      # fields were translatable (`human_attribute_name`) and the heading above
      # them was not. `activerecord.models.story` -- the key every Rails
      # application knows, and the one `hobo new` leaves a file for -- had no
      # effect on any page Hobo painted.
      def title_of(model)
        return model.model_name.human if model.respond_to?(:model_name) && model.model_name.respond_to?(:human)
        model.name.demodulize.underscore.humanize
      end

      # And the plural, which is not the singular with an s in most languages.
      # Rails' `human(:count => 2)` answers with the translation when there is
      # one and with the singular when there is not -- so the English rule stays
      # as the fallback.
      def plural_of(model)
        if model.respond_to?(:model_name) && model.model_name.respond_to?(:human)
          plural = model.model_name.human(:count => 2, :default => "").to_s
          return plural if plural.present? && plural != title_of(model)
        end
        title_of(model).pluralize
      end

      # Rails keeps these, and they are never what a page is about.
      HOUSEKEEPING = %w[created_at updated_at id type].freeze

      # The fields a summary shows: everything but the name (which is the
      # heading), the children (collections, not summary material) and the
      # housekeeping columns -- a card that leads with "Created at" is a card
      # about the database, not about the record.
      def summary_fields(model)
        fields = fields_of(model) - [name_attribute_of(model)] - children_of(model) - HOUSEKEEPING
        fields.map { |field| belongs_to_name(model, field) || field }
      end

      # `category_id` is not what a page is about: `category` is. The model
      # already said so -- `belongs_to :category` names the foreign key -- so
      # the derived pages walk the association and get the record, which <view>
      # paints as its name and <input> offers as a select of the categories
      # this user may see. Before this, every belongs_to came out as the number
      # in the column, on the index, on the record page and in the form.
      #
      # Polymorphic ones are left alone: there is no single class to ask for
      # choices, and pretending otherwise raises at render time.
      def belongs_to_name(model, field)
        return nil unless model.respond_to?(:reflections)
        reflection = model.reflections.values.find do |r|
          r.macro == :belongs_to && !r.options[:polymorphic] && r.foreign_key.to_s == field.to_s
        end
        reflection&.name&.to_s
      rescue StandardError
        nil
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
            # Con su nombre de papel, para que un tema pueda vestirlo: el
            # enlace de una tarjeta salía subrayado y en peso normal, donde el
            # de Hobo 2 iba en negrita y limpio.
            tag("h3", { :class => "card-title" }, :heading) do
              # A card nobody can click is a list nobody can use. The link is a
              # param of its own so a theme can change it without losing it.
              param(:name) do
                path = path_for(this)
                if path
                  # Con su papel, `card-link`, porque el enlace de una tarjeta
                  # no se ve como un enlace dentro de un texto: va en negrita y
                  # sin subrayar -- la caja entera ya dice que es un sitio al
                  # que ir. Bootstrap subraya todos los enlaces, así que sin
                  # esto no había manera de quitárselo.
                  tag("a", { :href => path, :class => "card-link" }, :link) do
                    call_tag(:name_view, {}, :as => :name_view)
                  end
                else
                  call_tag(:name_view, {}, :as => :name_view)
                end
              end
            end
            # Lo que la tarjeta **no** repite:
            #
            #   - `except`: el campo que apunta a donde ya estás. Dentro de la
            #     ficha de un libro, cada etiqueta decía «Libro: Los santos
            #     inocentes» debajo del título de la propia página.
            #   - y lo que ya es el título de la tarjeta. Un modelo de unión no
            #     tiene campo nombre, así que su título es su `to_s` -- que
            #     suele ser justo uno de sus campos --, y salía dos veces
            #     seguidas: «clasico» y debajo «Etiqueta: clasico».
            #
            # Las dos son la misma regla: no digas otra vez lo que acabas de
            # decir. Es lo que hacía la tarjeta de Hobo 2, que en un caso así
            # enseñaba solo el nombre.
            except = Array(attributes[:except]).map(&:to_s)
            title = begin
                      name_attribute ? this.send(name_attribute).to_s : this.to_s
                    rescue StandardError
                      nil
                    end

            shown = fields.reject do |field|
              next true if except.include?(field.to_s)
              (title.present? && this.send(field).to_s == title) rescue false
            end

            tag("dl", {}, :body) do
              shown.each do |field|
                with_field(field) do
                  tag("dt", {}, :"#{field}_label") { text HoboRapid::Derivation.label_for(model, field) }
                  tag("dd", {}, :"#{field}_value") { call_tag(:view, {}, :as => :"#{field}_view") }
                end
              end
            end
          end
        end
      end

      # The page for one record.
      #
      # The shape is Hobo 2's, because two applications built the same way
      # should look the same: a header panel with the record's name and what you
      # can do to it, then the description, then the rest of the fields, then a
      # section per collection with its own "new" link.
      #
      # (Hobo 2 painted `<h2>` inside `<content-header class="well">`, which was
      # Bootstrap 2's grey panel. The panel is a card now; the heading level is
      # the same.)
      def derive_show_page(model)
        name_attribute = name_attribute_of(model)
        description = description_attribute_of(model)
        fields = summary_fields(model) - [description].compact
        children = children_of(model)

        Rapid.define_for(:show_page, model) do
          # At render time: see the note in derive_index_page. The name of a
          # model belongs to the language of the request.
          title = HoboRapid::Derivation.title_of(model)
          heading = name_attribute ? this.send(name_attribute).to_s : model.name.demodulize
          in_page("#{title} #{heading}") do
            tag("article", { :class => "show-page #{model.name.demodulize.underscore}" }, :body) do

              tag("div", { :class => "content-header" }, :content_header) do
                tag("div", { :class => "header-line" }) do
                  tag("h2", {}, :heading) do
                    text "#{title} "
                    param(:name) do
                      if name_attribute
                        with_field(name_attribute) { call_tag(:view, { :no_wrapper => true }, :as => :name_view) }
                      else
                        text this.to_s
                      end
                    end
                  end
                  call_tag(:record_actions, { :style => "buttons" }, :as => :record_actions)
                end
              end

              tag("div", { :class => "content-body" }, :content_body) do
                if description
                  with_field(description) do
                    tag("div", { :class => "description" }, :description) { call_tag(:view, {}, :as => :description_view) }
                  end
                end

                tag("dl", { :class => "field-list" }, :field_list) do
                  fields.each do |field|
                    with_field(field) do
                      tag("dt", { :class => "field-label" }, :"#{field}_label") { text HoboRapid::Derivation.label_for(model, field) }
                      tag("dd", { :class => "field-value" }, :"#{field}_value") { call_tag(:view, {}, :as => :"#{field}_view") }
                    end
                  end
                end

                children.each do |child|
                  tag("section", { :class => "collection-section #{child}" }, :"#{child}_section") do
                    tag("div", { :class => "header-line" }) do
                      # Por el mismo camino que las etiquetas de los campos:
                      # `child.humanize` decía «Book tags» en una ficha en la
                      # que todo lo demás estaba en castellano, porque
                      # humanizaba el nombre de la asociación en vez de
                      # preguntarle a Rails cómo se llama.
                      tag("h3", {}, :"#{child}_heading") { text HoboRapid::Derivation.label_for(model, child) }
                    end
                    # **Tarjetas, no una lista con viñetas.**
                    #
                    # Lo que cuelga de una ficha son registros, y un registro se
                    # pinta con su `<card>` -- que es una caja con su nombre y
                    # su enlace, y que esta misma máquina deriva para cada
                    # modelo. Pintarlo con `<view>` daba un `<ul>` de nombres:
                    # la misma información, con aspecto de nota al pie. Hobo 2
                    # pintaba tarjetas aquí, y se nota.
                    # El campo del hijo que apunta a esta página, para que la
                    # tarjeta no lo repita: en `Book has_many :book_tags`, la
                    # clave es `book_id`, o sea el campo `book`.
                    back_reference = HoboRapid::Derivation.reference_back(model, child)

                    with_field(child) do
                      tag("div", { :class => "collection-cards" }, :"#{child}_collection") do
                        Array(this).each do |record|
                          with_this(record) do
                            if Rapid.polymorphic?(:card, record)
                              call_tag(:card, { :except => back_reference }, :as => :"#{child}_card")
                            else
                              # Un modelo sin tarjeta derivada -- uno que no pasó
                              # por `derive`: se pinta como se pintaba.
                              call_tag(:view, { :force => true }, :as => :"#{child}_card")
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      # The page for the collection: a header panel with the name and the count,
      # a "new" link, and **a table** -- which is what hobo_bootstrap painted.
      def derive_index_page(model)
        columns = index_columns(model)
        Rapid.define_for(:index_page, model) do
          records = Array(this)

          # Asked **here** and not when the page was derived. Deriving happens
          # once, at boot; rendering happens on every request, and the language
          # belongs to the request -- `I18n.locale` can be set per person. A
          # name captured at derivation time is the language the server started
          # in, for ever, which is how a Spanish application kept saying
          # "Stories" above a table whose headings were in Spanish.
          plural = HoboRapid::Derivation.plural_of(model)
          singular = HoboRapid::Derivation.title_of(model)
          in_page(plural) do
            tag("div", { :class => "index-page #{model.name.demodulize.underscore.pluralize}" }, :body) do

              tag("div", { :class => "content-header" }, :content_header) do
                tag("div", { :class => "header-line" }) do
                  tag("div") do
                    tag("h2", {}, :heading) { text plural }
                    tag("p", { :class => "count" }, :count) do
                      text(records.length == 1 ? t(:"index.count_one", "1 %{name}", :name => singular.downcase)
                                               : t(:"index.count", "%{count} %{name}", :count => records.length, :name => plural.downcase))
                    end
                  end

                  new_path = new_path_for(model)
                  if new_path && creatable_here?(model)
                    tag("a", { :href => new_path, :class => "action new" }, :new_link) do
                      text t(:"index.new_link", "New %{name}", :name => singular.downcase)
                    end
                  end
                end
              end

              tag("div", { :class => "content-body" }, :content_body) do
                with_actions = records.any? { |record| with_this(record) { editable_here? || destroyable_here? } }

                # An empty extension point above the list, and the only way an
                # application can put filters on a derived index without taking
                # the whole page over. Empty by default on purpose (decision
                # 18): a list that grows a select for every column is not a
                # decision, it is a pile.
                #
                #   # app/views/movies/index.html.erb
                #   <%= rapid_tag :index_page, @movies, :filters => Rapid.markup {
                #         call_tag(:search_filter, :fields => "title, synopsis")
                #         call_tag(:filter_menu, :field => "category")
                #       } %>
                tag("div", { :class => "filters" }, :filters)

                if records.empty?
                  tag("p", { :class => "empty" }, :empty) { text t(:"index.empty", "Nothing here yet.") }
                else
                  tag("table", { :class => "collection-table" }, :collection) do
                    tag("thead", {}, :headings) do
                      tag("tr") do
                        columns.each do |field|
                          tag("th", {}, :"#{field}_heading") { text HoboRapid::Derivation.label_for(model, field) }
                        end
                        tag("th", { :class => "actions" }, :actions_heading) { text t(:"index.actions_heading", "Actions") } if with_actions
                      end
                    end

                    tag("tbody", {}, :rows) do
                      records.each do |record|
                        with_this(record) do
                          tag("tr", {}, :row) do
                            columns.each_with_index do |field, index|
                              tag("td", {}, :"#{field}_cell") do
                                if index.zero?
                                  path = path_for(this)
                                  if path
                                    tag("a", { :href => path }, :name_link) { call_tag(:name_view, {}, :as => :name_view) }
                                  else
                                    call_tag(:name_view, {}, :as => :name_view)
                                  end
                                else
                                  with_field(field) { call_tag(:view, {}, :as => :"#{field}_view") }
                                end
                              end
                            end

                            if with_actions
                              tag("td", { :class => "actions" }, :actions) { call_tag(:record_actions, {}, :as => :record_actions) }
                            end
                          end
                        end
                      end
                    end
                  end
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

        # The children go in the form too, and they were the piece missing: a
        # collection you can only fill in from another page is not a nested
        # form, and creating a genre from inside the film is the thing Hobo was
        # known for. They come last, after the fields, because a row of rows is
        # bigger than a field and reads badly in the middle of them.
        children = children_of(model)

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

            children.each do |child|
              with_field(child) do
                tag("div", { :class => "field children" }, :"#{child}_field") do
                  tag("label", {}, :"#{child}_label") { text HoboRapid::Derivation.label_for(model, child) }
                  call_tag(:input_many, {}, :as => :"#{child}_input")
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
          name = HoboRapid::Derivation.title_of(model).downcase
          title = new_record ? t(:"forms.new_title", "New %{name}", :name => name)
                             : t(:"forms.edit_title", "Edit %{name}", :name => name)

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

                # El pie del formulario: guardar **y volver sin guardar**.
                #
                # Faltaba lo segundo, y en Hobo 2 estaba: un formulario del que
                # solo se sale enviándolo o con el botón de atrás del navegador
                # no está terminado. Y va en su propia franja -- `form-actions`,
                # que es el nombre que usaba aquel tema -- porque separar los
                # botones de los campos es lo que hace que se vean como botones
                # de la página y no como un campo más.
                #
                # `submit` y no `new`: el papel de este botón es enviar. Con
                # `new` se vestía como el «Nuevo libro» del listado, que es otra
                # cosa que casualmente también es azul.
                tag("div", { :class => "actions form-actions" }, :actions) do
                  tag("button", { :type => "submit", :class => "action submit" }, :submit) do
                    text(new_record ? t(:"actions.create", "Create") : t(:"actions.save", "Save"))
                  end
                  back = new_record ? path_for(model) : path_for(this)
                  if back
                    tag("a", { :href => back, :class => "action cancel" }, :cancel) do
                      text t(:"actions.cancel", "Cancel")
                    end
                  end
                end
              end
            end
          end
        end
      end

      public

      # The columns of a list's table, in order. Public because a taglib that
      # wants to touch the headings needs the same names the page used -- if it
      # works them out again on its own, the day this changes the taglib
      # retouches params that no longer exist and nobody complains.
      def index_columns(model)
        ([name_attribute_of(model)] + summary_fields(model)).compact
      end

      def label_for(model, field)
        return model.human_attribute_name(field) if model.respond_to?(:human_attribute_name)
        field.to_s.humanize
      end

      # El campo con el que un hijo señala a su padre. `Book has_many
      # :book_tags` guarda `book_id` en el hijo, así que el campo es `book`.
      #
      # Sirve para no repetirlo: dentro de la ficha de un libro, la tarjeta de
      # cada etiqueta no tiene que decir de qué libro es.
      def reference_back(model, child)
        return nil unless model.respond_to?(:reflections)
        reflection = model.reflections[child.to_s]
        return nil unless reflection

        reflection.foreign_key.to_s.sub(/_id\z/, "")
      rescue StandardError
        nil
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

# What you can do to a record: the edit and delete of the old theme's actions
# column, and its Edit button on the record page. They appear only when the
# route exists and the user is allowed -- the permissions of piece 4 decide, not
# the markup.
Rapid.define(:record_actions, :attrs => [:style]) do
  buttons = attributes[:style].to_s == "buttons"
  edit = edit_path_for(this)
  destroy = path_for(this)

  tag("div", { :class => "record-actions" }, :actions) do
    if edit && editable_here?
      tag("a", { :href => edit, :class => buttons ? "action edit button" : "action-edit" }, :edit) do
        text(buttons ? t(:"actions.edit", "Edit") : "\u270E")
      end
    end

    if destroy && destroyable_here?
      # A delete is a POST with `_method`, never a link: a crawler that follows
      # links must not be able to empty the database.
      tag("form", { :method => "post", :action => destroy, :class => "inline" }, :delete_form) do
        param(:authenticity_token) { authenticity_token_field }
        tag("input", { :type => "hidden", :name => "_method", :value => "delete" })
        tag("button", { :type => "submit", :class => buttons ? "action delete button" : "action-delete",
                        :"data-turbo-confirm" => t(:"actions.confirm_delete", "Are you sure?") }, :delete) do
          text(buttons ? t(:"actions.delete", "Delete") : "\u2716")
        end
      end
    end
  end
end
