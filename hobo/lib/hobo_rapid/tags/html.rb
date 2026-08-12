# The html tags of the catalogue.
#
# They look like a formality and they are not. DRYML decides whether a name is
# an element or a tag call from a **list** -- `static_tags`, 98 names -- and
# `a`, `img`, `br`, `form`, `input`, `table`, `section` and `header` are **not
# on it**. They are tag calls, and this is what they call.
#
# So `<a>` in a template is not `<a>` in html. It is this one, which works out
# the url from the record it is painting:
#
#   <a with="&book">Leer</a>       ->  <a href="/books/1">Leer</a>
#   <a with="&Book">El catalogo</a> ->  <a href="/books">El catalogo</a>
#   <a with="&book"/>              ->  <a href="/books/1">Rayuela</a>
#
# And when the route does not exist -- no controller, or the action is turned
# off -- it paints **the text without the link** rather than a link to nowhere.
# That is the whole point of the tag: a template says "a link to this book" and
# does not have to know whether books have a page.
#
# Ported from Hobo 2's `hobo_rapid/taglibs/html/` (2026-08-11). Written in Ruby
# and not left as DRYML in a gem: the catalogue is the catalogue, and it cannot
# depend on the optional language.

require "rapid"

# --- the void elements ---------------------------------------------------------
#
# `<br>`, `<img>`, `<meta>`… all the same thing: an element with no content that
# takes whatever attributes it is given. `<empty-tag tag-name="x"/>` is the one
# old templates write when the name is worked out at render time.

Rapid.define(:empty_tag, :attrs => [:tag_name]) do
  name = attributes[:tag_name] || "br"
  tag(name.to_s, all_attributes.except(:tag_name, "tag_name"))
end

# And `<img>`, `<br>`, `<meta>`, `<link>`, `<hr>`, `<base>`, `<frame>`,
# `<area>`, `<col>` and `<param>` are **not here** (2026-08-11, with Imanol).
#
# Hobo 2 defined them, and they did nothing: `<def tag="img"><empty-tag
# tag-name="img" merge/></def>`. They existed because DRYML's list of element
# names is short and those are not on it, so `<img>` in a template was a call
# to a tag that had to exist. Plumbing for the language, not catalogue.
#
# They are on `hobo_dryml`'s list now, so `<img src="x"/>` in a `.dryml` comes
# out as it always did, and `hobo.img` -- which nobody would write, because in
# a template you write `<img>` -- is gone. Checked against 807 templates of
# ~20 real applications: the only redefinition is three copies of `<def
# tag="br">` that are letter for letter what Hobo already did.
#
# It also settles a name: `param` was a tag **and** the verb that fills in a
# param, and `hobo.param` could only be one of them.

# --- the link ------------------------------------------------------------------

# `<a>`: a link to whatever is being painted.
#
# With `href` it is an ordinary link and nothing is worked out. Without it, the
# url comes from `this` -- a record goes to its page, a model class to its
# index -- and `action` asks for another one (`new`, `edit`).
Rapid.define(:a, :attrs => [:action, :href]) do
  href = attributes[:href]
  action = attributes[:action]

  href ||= case action.to_s
           when "new"  then new_path_for(this)
           when "edit" then edit_path_for(this)
           else path_for(this)
           end

  rest = all_attributes.except(:action, "action", :href, "href")

  # No route: the content, with no link. A link to nowhere is worse than plain
  # text, and this is what let a template say "a link to this" without knowing
  # whether the thing has a page.
  if href.nil?
    param(:default) { call_tag(:name_view) }
    next
  end

  tag("a", rest.merge("href" => href)) do
    # With no content of its own, a link says the name of what it points at.
    param(:default) { call_tag(:name_view) }
  end
end

# --- the sections of a document ------------------------------------------------
#
# `<header>`, `<footer>`, `<section>` and `<aside>` are off the static list too,
# so a template that writes one is calling a tag. They are the html5 elements
# with an extension point inside, which is what makes them worth calling.

%w[header footer section aside nav].each do |name|
  Rapid.define(name.to_sym) do
    tag(name, all_attributes) { param(:default) }
  end
end

# A run of sections with a heading, which is how Hobo 2 built the body of a show
# page.
Rapid.define(:section_group) do
  tag("div", all_attributes.merge("class" => ["section-group", all_attributes["class"]].compact.join(" "))) do
    param(:default)
  end
end

# --- the document --------------------------------------------------------------

Rapid.define(:doctype) { raw("<!DOCTYPE html>\n") }

Rapid.define(:html) do
  tag("html", all_attributes) { param(:default) }
end

# `<if-ie>`: a conditional comment for a browser that has not existed since
# 2022. It is kept because old templates carry it and it costs one line; what it
# paints is a comment, which every browser ignores.
Rapid.define(:if_ie, :attrs => [:version]) do
  condition = ["if IE", attributes[:version]].compact.join(" ")
  raw("<!--[#{condition}]>")
  param(:default)
  raw("<![endif]-->")
end

# `<image>`: an `<img>` whose `src` goes through the asset pipeline, which is
# what tells it apart from writing `<img>` by hand.
Rapid.define(:image, :attrs => [:name, :alt]) do
  name = attributes[:name].to_s
  source = if defined?(Rails) && Rails.respond_to?(:application) && Rails.application &&
              Rails.application.respond_to?(:assets) && Rails.application.assets
             (Rails.application.assets.load_path.find(name)&.digested_path&.to_s&.prepend("/assets/") rescue nil) || name
           else
             name
           end

  tag("img", all_attributes.except(:name, "name").merge("src" => source, "alt" => attributes[:alt].to_s))
end
