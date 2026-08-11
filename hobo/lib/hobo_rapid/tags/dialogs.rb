# Dialogs, and the odds and ends the themes used to own. Ported 2026-08-11.
#
#   <%= hobo.modal :title => "Nuevo cliente" do %>…<% end %>
#   <%= hobo.modal_open_button :modal => "nuevo-cliente" %>
#
# In Hobo 2 these lived in `hobo_bootstrap_ui`, a gem whose whole job was to
# paint Bootstrap's javascript components. They are here because a dialog is
# **structure** -- it is where the content goes -- and because the piece that
# made them need a gem is gone: `<dialog>` is a real html element since 2022,
# every browser has it, and it opens and closes with no javascript library.
#
# The theme dresses it, like everything else: `modal` is a role.

require "rapid"
require "hobo_rapid/tags/structure"

# `<modal>`: a dialog, closed until something opens it.
#
# The id matters and is not decoration: `<modal-open-button modal="x">` names it,
# and so does anything else that wants to open this one rather than another.
Rapid.define(:modal, :attrs => [:title, :id, :open]) do
  name = attributes[:id] || "modal"
  rest = all_attributes.except(:title, "title", :id, "id", :open, "open")

  tag("dialog", rest.merge("id" => name, "class" => ["modal", rest["class"]].compact.join(" "),
                           **(attributes[:open] ? { "open" => true } : {})), :modal) do
    call_tag(:modal_header, { :title => attributes[:title] }, :as => :header) if attributes[:title]
    tag("div", { "class" => "modal-body" }, :body) { param(:default) }
  end
end

Rapid.define(:modal_header, :attrs => [:title]) do
  tag("div", { "class" => "modal-header" }, :header) do
    tag("h5", { "class" => "modal-title" }, :title) { param(:default) { text attributes[:title].to_s } }
    # The way out. A dialog you can only leave by submitting it is the same
    # trap `<or-cancel>` was written for.
    tag("button", { "type" => "button", "class" => "action close",
                    "formmethod" => "dialog", "aria-label" => "Cerrar" }, :close) { raw("&times;") }
  end
end

# The foot of a form inside a dialog: send it, or close it.
Rapid.define(:modal_form_footer, :attrs => [:label]) do
  tag("div", { "class" => "modal-footer" }, :footer) do
    param(:default) do
      call_tag(:submit, { :label => attributes[:label] }, :as => :submit)
      tag("button", { "type" => "button", "class" => "action cancel", "formmethod" => "dialog" }, :close) do
        text t(:"actions.cancel", "Cancel")
      end
    end
  end
end

# What opens one. `<dialog>` opens with `showModal()`, and that one line is what
# the whole gem was for.
Rapid.define(:modal_open_button, :attrs => [:modal, :label]) do
  target = attributes[:modal].to_s

  tag("button", { "type" => "button", "class" => "action",
                  "onclick" => "document.getElementById('#{target}').showModal()" }, :button) do
    param(:default) { text(attributes[:label] || t(:"actions.open", "Open")) }
  end
end

Rapid.define(:modal_and_button, :attrs => [:modal, :label, :title]) do
  call_tag(:modal_open_button, { :modal => attributes[:modal], :label => attributes[:label] }, :as => :button)
  call_tag(:modal, { :id => attributes[:modal], :title => attributes[:title] }, :as => :modal) { param(:default) }
end

# --- the ones the themes had ---------------------------------------------------

# `<alert-box>`: a message that is not a flash -- one the page puts there on
# purpose, and that stays.
Rapid.define(:alert_box, :attrs => [:type]) do
  kind = (attributes[:type] || "info").to_s
  tag("div", { "class" => "alert alert-#{kind}", "role" => "alert" }, :alert) { param(:default) }
end

# `<sub-nav>`: the second row of navigation, under the bar. A section's own
# menu, which is what an application with an /admin or a long section grows.
Rapid.define(:sub_nav) do
  tag("nav", { "class" => "sub-nav" }, :nav) do
    tag("ul", { "class" => "subnav-list" }, :items) { param(:default) }
  end
end

# `<simple-page>`: a page with no navigation and no aside -- a login, an error,
# a printable. `<page>` with the furniture taken away, which is what its params
# are for.
Rapid.define(:simple_page, :attrs => [:title]) do
  call_tag(:page, { :title => attributes[:title] }, :as => :page,
           :without_nav => true, :without_aside => true) do
    param(:default)
  end
end
