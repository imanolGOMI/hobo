# The form tags of the catalogue, ported from Hobo 2 (2026-08-11).
# The derived pages already paint a form and a list of fields, but **inline**,
# so an application could not write one of its own. These are the same thing as
# tags, which is what a template needs to say:
#
#   <form><field-list fields="titulo, autor"/><submit label="Guardar"/></form>
#
# `field-list` is the most used tag of Hobo 2's whole catalogue -- 65 times in
# amenti alone -- and it is the one that pays for itself: a list of fields is
# label plus control, over and over, and the only thing that changes between a
# page that shows and a page that edits is which control.
#
# ## Why they are not extracted from the derived pages yet
#
# `derive_form` and `derive_show_page` still paint their own rows. Making them
# call these would be the right refactor and it changes what every derived page
# emits, so it is a change of its own with its own before-and-after -- not
# something to slip in while adding tags.

require "rapid"
# For `authenticity_token_field`, which every form needs: Rails answers 422
# without it.
require "hobo_rapid/tags/structure"

# `<field-list fields="titulo, autor">`: the rows of a record.
#
# Each row is a label and a control, and which control it is comes from `mode`:
# `view` shows and `input` edits. Inside a `<form>` it defaults to editing,
# which is what made the tag usable without saying so every time.
Rapid.define(:field_list, :attrs => [:fields, :mode]) do
  names = attributes[:fields].to_s.split(",").map(&:strip).reject(&:empty?)
  names = HoboRapid::Derivation.index_columns(this.class) if names.empty? && this.respond_to?(:class)

  # `scope[:in_form]` and not `scope.in_form`: the scope raises for a name
  # nobody set, which is right -- a typo should not answer nil -- and this is a
  # question, not a name. `<form>` is what sets it.
  mode = (attributes[:mode] || (scope[:in_form] ? "input" : "view")).to_s
  record = this

  tag("div", { :class => "field-list" }, :field_list) do
    names.each do |field|
      with_field(field, record) do
        tag("div", { :class => "field" }, :"#{field}_field") do
          tag("label", {}, :"#{field}_label") do
            text HoboRapid::Derivation.label_for(record.class, field)
          end
          call_tag(mode == "input" ? :input : :view, {}, :as => :"#{field}_#{mode}")
        end
      end
    end
  end
end

# `<form>`: the element, with the url worked out from the record.
#
# A new record posts to the collection and an existing one patches its own url,
# which is the whole of what `form_helper` did in Hobo 2 that anybody noticed.
# The forgery token goes in as a param so a theme or an application can replace
# it -- and so that a form painted outside Rails still has the extension point.
Rapid.define(:form, :attrs => [:action, :method]) do
  new_record = this.respond_to?(:new_record?) && this.new_record?
  target = attributes[:action] || path_for(new_record ? this.class : this)
  verb = (attributes[:method] || "post").to_s

  rest = all_attributes.except(:action, "action", :method, "method")
  classes = ["hobo-form", rest[:class] || rest["class"]].compact.join(" ")

  tag("form", rest.merge("method" => verb, "action" => target, "class" => classes), :form) do
    # Rails needs to be told it is an update: html forms only know GET and POST.
    tag("input", { :type => "hidden", :name => "_method", :value => "patch" }) if !new_record && verb == "post"
    param(:authenticity_token) { authenticity_token_field }

    # And everything inside now knows it is in a form, which is how a
    # `<field-list>` written with no `mode` comes out editable.
    Rapid::Context.with(:scope => scope.merge(:in_form => true)) { param(:default) }
  end
end

# `<formlet>`: the inside of a form without the `<form>`.
#
# It is what you write for a part of a bigger form -- a nested record, a section
# that is submitted with the rest -- and the reason it exists is that a `<form>`
# inside a `<form>` is not valid html and browsers drop it silently.
Rapid.define(:formlet) do
  tag("div", all_attributes.merge("class" => ["formlet", all_attributes["class"]].compact.join(" "))) do
    param(:default)
  end
end

# `<one-line-form fields="titulo, autor">`: crear sin cambiar de pagina.
#
# El formulario de alta puesto **encima de su propio listado**, en una linea: se
# escribe y se anade, y lo que se acaba de crear aparece debajo. Es de las cosas
# que mas se agradecen de una aplicacion de gestion, y por eso las plantillas lo
# usan tanto.
#
# En Hobo 2 vivia en el tema, que era una gema con `<page>` dentro y podia
# pintar. El tema de Hobo 3 **no pinta**: es una tabla de nombres de clase. Asi
# que la forma es del catalogo -- una fila de campos y un boton -- y como se
# viste lo dice el tema, que es el reparto de siempre.
#
# `fields` va al `<field-list>` y no al `<form>`: escrito en el `<form>` sale
# como un atributo html llamado `fields`, que es lo que pasaba, y ademas no
# pinta ningun campo.
Rapid.define(:one_line_form, :attrs => [:fields]) do
  rest = all_attributes.except(:fields, "fields")
  classes = ["one-line-form", rest[:class] || rest["class"]].compact.join(" ")

  call_tag(:form, rest.merge(:class => classes), :as => :form) do
    fields = attributes[:fields]
    call_tag(:field_list, fields ? { :fields => fields, :mode => "input" } : { :mode => "input" },
             :as => :field_list)
    call_tag(:submit, { :label => t(:"actions.create", "Create") }, :as => :submit)
  end
end

# `<submit label="Guardar"/>`
Rapid.define(:submit, :attrs => [:label, :image]) do
  image = attributes[:image]
  rest = all_attributes.except(:label, "label", :image, "image")

  if image
    tag("input", rest.merge("type" => "image", "src" => image,
                            "class" => ["action submit image-button", rest["class"]].compact.join(" ")))
  else
    tag("button", rest.merge("type" => "submit",
                             "class" => ["action submit", rest["class"]].compact.join(" ")), :submit) do
      param(:default) { text(attributes[:label] || t(:"forms.submit", "Save")) }
    end
  end
end

# `<or-cancel/>`: the way out of a form that is not sending it.
#
# It was missing from the derived pages until the theme work and it is not a
# nicety: a form you can only leave by submitting it or by pressing back is a
# form that traps you. It paints nothing when there is nowhere to go back to,
# which is the same rule `<a>` follows.
Rapid.define(:or_cancel) do
  back = path_for(this) || path_for(this.class)
  next if back.nil?

  text " #{t(:"support.or", "or")} "
  tag("a", all_attributes.merge("href" => back, "class" => ["action cancel", all_attributes["class"]].compact.join(" "))) do
    param(:default) { text t(:"actions.cancel", "Cancel") }
  end
end
