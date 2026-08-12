# <view>: how a value is painted, decided by its type.
#
# This is the heart of piece 9. `<view:body/>` does not say how to paint the
# body -- it says "paint this field", and the type decides. A `:markdown` field
# comes out as html, a `:date` as a formatted date, a boolean as a tick.
#
# The dispatch is the runtime's (Rapid.define_for), and it goes on the field's
# **declared** type, so a blank field still paints as the kind of thing it is.

require "rapid"
require "hobo_rapid/request"

module HoboRapid

  # Raised instead of naming Hobo::PermissionDeniedError, so the catalogue can
  # be loaded and tested without the whole of Hobo.
  class PermissionDenied < RuntimeError; end

  module Tags

    # Everything <view> needs to know about the field it is painting, kept in
    # one place because these questions always travel together.
    module ViewSupport

      # `story.title` -> "story-title", which is what a stylesheet hangs off.
      def type_and_field
        return nil unless this_parent && this_field
        "#{this_parent.class.name.demodulize}-#{this_field}".underscore.dasherize
      end

      def can_view?
        return true unless this_parent && this_field
        return true unless this_parent.respond_to?(:viewable_by?)
        this_parent.viewable_by?(acting_user, this_field)
      end

      # Who is asking. `rapid_tag` takes the controller's `current_user` and
      # puts it where the tags can reach it (HoboRapid.with_request), and this
      # is the other end of that wire.
      #
      # It used to answer `nil`, always, with a note saying it would be wired
      # through later. Nothing failed: every permission question got the answer
      # for a guest, so forms came out read-only, the actions column disappeared
      # and no page ever complained. **A tag that asks a question it always
      # answers itself is not asking anything**, which is why the piece tests
      # passed while the product had no forms.
      def acting_user = HoboRapid.current_user

      # A collection paints as a list of its members, not as itself.
      def collection?
        this.respond_to?(:each) && !this.is_a?(String) && !this.is_a?(Hash)
      end

    end

  end
end

Rapid::Tag.include(HoboRapid::Tags::ViewSupport)

# `<view>` and the type views are **two** tags, not one, and that is not an
# accident: a polymorphic definition *replaces* the whole tag, so if the type
# views were `<view>` itself they would lose the permission check, the wrapper
# and the blank handling. So `<view>` keeps all of that and delegates the paint
# to `<view-content>`, which is the polymorphic one. DRYML had the same pair.
Rapid.define(:view, :attrs => [:if_blank, :inline, :block, :no_wrapper, :truncate, :force, :html]) do
  unless attributes[:force] || can_view?
    raise HoboRapid::PermissionDenied, "the field '#{this_field}' cannot be seen"
  end

  # A blank value never reaches the type view -- there is nothing to paint and
  # `nil` does not answer to what a type view would ask of it. The wrapper is
  # still painted, so the page does not jump about when a value appears.
  painted = if this.nil?
              ""
            elsif collection?
              capture { param(:default) { call_tag(:collection_view, {}, :as => :collection) } }
            else
              capture { param(:default) { call_tag(:view_content) } }
            end

  painted = attributes[:if_blank].to_s if painted.blank? && attributes[:if_blank]
  painted = painted.to_s[0, attributes[:truncate].to_i] if attributes[:truncate]

  if attributes[:no_wrapper]
    raw painted
  else
    wrapper = attributes[:block] ? "div" : "span"
    classes = ["view", type_and_field].compact.join(" ")
    tag(wrapper, { :class => classes }.merge(attributes[:html] || {})) { raw painted }
  end
end

# The paint itself, decided by the type.
#
# The default already covers the rich types, and that is the point of them: a
# Markdown, a Textile, an EnumString or a LifecycleState **knows how to paint
# itself**, through `to_html`. The catalogue does not need a view per rich type;
# the type carries it, which is what "tipos ricos que viajan a la vista" means.
Rapid.define(:view_content) do
  name_attribute = this.class.respond_to?(:name_attribute) && this.class.name_attribute

  if this.respond_to?(:to_html)
    raw this.to_html
  elsif this.class.respond_to?(:name_attribute) # un registro
    # A record paints as its name, not as its inspect. Which field is its name
    # is something the model already said, so nobody has to say it again -- y si
    # no lo dijo, su `to_s`, que es lo que un modelo de unión define para no
    # llamarse «Book tag 1».
    #
    # **And as a link**, which is what Hobo 2 did and this had lost: a record is
    # a place, and painting its name without a way to get there is showing
    # somebody a door and not letting them open it. It is the `belongs_to` of
    # every table -- the category of a film, the project of a story -- and it
    # was a dead end on every page.
    #
    # El enlace dependía de tener campo nombre, y eso dejaba fuera justo a los
    # que no lo tienen: las etiquetas de un libro salían como texto plano en la
    # ficha, donde Hobo 2 pinta una lista de enlaces.
    #
    # `path_for` belongs to the derivation engine, and the catalogue has to
    # paint without it (that is what the piece tests do), so it asks first.
    path = respond_to?(:path_for) ? path_for(this) : nil
    name = name_attribute ? this.send(name_attribute).to_s : this.to_s

    if path
      tag("a", { :href => path, :class => "record-link" }, :link) { text name }
    else
      text name
    end
  else
    text this.to_s
  end
end

Rapid.define_for(:view_content, Date)    { text this.strftime("%Y-%m-%d") }
Rapid.define_for(:view_content, Time)    { text this.strftime("%Y-%m-%d %H:%M") }
Rapid.define_for(:view_content, Numeric) { text this.to_s }
Rapid.define_for(:view_content, Rapid::Boolean) { raw(this ? "&#10004;" : "&#10008;") }

# A record paints as its name, not as its inspect. Which field is its name is
# something the model said with `fields do`, so nobody has to say it again.
Rapid.define(:record_view_content) do
  field = this.class.respond_to?(:name_attribute) && this.class.name_attribute
  field ? text(this.send(field).to_s) : text(this.to_s)
end


# Una contraseña **no se pinta**, y esto no es una cuestión de estilo: sin esta
# línea la vista por defecto hace `this.to_s`, así que un campo declarado
# `password :clave` salía escrito en la página a quien tuviera permiso de verlo
# -- y en una página derivada lo tiene cualquiera que pueda ver el registro.
#
# Lo encontró la matriz de tipos: no aparece pintando un `string`, aparece
# cuando pruebas los diecisiete.
Rapid.define_for(:view_content, HoboFields::Types::PasswordString) do
  text("••••••")
end if defined?(HoboFields::Types::PasswordString)

# A `has_many` paints as a list of the views of its members. Anything that
# answers to `each` and is not a string counts.
Rapid.define(:collection_view, :attrs => [:tag]) do
  wrapper = attributes[:tag] || "ul"
  tag(wrapper, { :class => "collection-view" }, :collection) do
    Array(this).each do |member|
      # Every one of these is an extension point on purpose: without them a
      # theme could not say how a member is painted, and the param contract
      # sweep of layer 3 is what caught that they were missing.
      with_this(member) do
        tag("li", {}, :item) { call_tag(:view, { :force => true }, :as => :member) }
      end
    end
  end
end
