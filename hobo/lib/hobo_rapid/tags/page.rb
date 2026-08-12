# `<page>`: the whole document, and the contract with a theme (piece 13b).
#
# It used to live inside `hobo_bootstrap`, and that meant **there could only be
# one theme**: anybody who did not want Bootstrap got no page at all, or a page
# full of class names that meant nothing without it. The page belongs to the
# catalogue now and says the **role** of each part -- `navbar`, `brand`,
# `content`, `aside` -- and a theme puts its own names on top of those
# (`Rapid.class_map`) and brings its stylesheet.
#
# The ~30 named extension points are still the contract: an application changes
# one corner of a page without taking over the whole page. That is what made the
# param mechanism of layer 3 worth carrying.
#
# The column sizes (`content-9`, `aside-3`) are said in twelfths, as they always
# were: another name for a theme to dress -- Bootstrap turns them into `col-9`
# -- and not somebody else's class.

require "rapid"
require "hobo_rapid/tags/structure"
require "hobo_rapid/theme"

module HoboRapid

  module PageSupport

    # The application's name, which is the application's and not the tool's:
    # `hobo3_mi_app`'s bar said "Hobo". Rails knows it, and the front page's
    # controller was already passing it by hand -- what was missing was for the
    # derived pages, which pass nothing, to have it too.
    def app_name
      return "Hobo" unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      Rails.application.class.module_parent_name.titleize
    rescue StandardError
      "Hobo"
    end
    def subsite = nil
    def base_url = ""
    # Rails' token, in the page's head.
    #
    # It was `nil` -- a gap that was never filled -- and it went unnoticed
    # because forms carry their own in a hidden field. What does not work
    # without this is **any POST from javascript**: there is nowhere to take the
    # token from and Rails answers 422. `sortable-collection` found it while
    # saving a new order, which is exactly that case.
    #
    # The token already travels: `rapid_tag` leaves it in HoboRapid for the rest
    # of the render, because the forms need it too.
    def csrf_meta_tag
      token = HoboRapid.authenticity_token if defined?(HoboRapid)
      return nil if token.nil? || token.to_s.empty?

      %(<meta name="csrf-param" content="authenticity_token">) +
        %(<meta name="csrf-token" content="#{CGI.escapeHTML(token.to_s)}">)
    end

    # Assets go through Rails' own resolver, which is the only thing that knows
    # where a file ends up: Propshaft serves digested names, and a hardcoded
    # `/assets/bootstrap.css` is a 404 waiting to happen. Outside Rails it falls
    # back to the plain path so the tags can still be tested on their own.
    def asset_path_for(name, extension)
      file = "#{name}.#{extension}"
      if defined?(ActionController::Base)
        begin
          return ActionController::Base.helpers.asset_path(file)
        rescue StandardError
          nil
        end
      end
      "/assets/#{file}"
    end

  end

end

Rapid::Tag.include(HoboRapid::PageSupport)

Rapid.define(:page, :attrs => [:title, :full_title, :nav_location, :aside_location,
                               :content_size, :aside_size, :bottom_load_javascript]) do
  # The name comes from the **tag** `<app-name>` and not from the helper of the
  # same name.
  #
  # Redefining that tag is how an application says what it is called -- amenti
  # puts "Aplicacion para Gestion de Funerarias y Tanatorios | Amenti Software"
  # there -- and the title went on saying the name of the Rails directory. The
  # markup is stripped because a `<title>` is text and the tag may bring a link.
  written_name = Rapid::Context.capture { call_tag(:app_name) }.to_s.gsub(/<[^>]*>/, "").strip
  written_name = app_name if written_name.empty?
  full_title = attributes[:full_title] || [attributes[:title], written_name].compact.join(" : ")
  has_aside = !all_parameters[:aside].nil?

  content_size = (attributes[:content_size] || (has_aside ? 9 : 12)).to_i
  aside_size = (attributes[:aside_size] || (12 - content_size)).to_i
  aside_location = attributes[:aside_location] || "right"
  nav_location = attributes[:nav_location]

  aside = proc do
    tag("div", { :class => "aside aside-#{aside_size}" }, :aside_column) do
      tag("aside", { :class => "aside-box" }, :aside)
    end
  end

  raw "<!DOCTYPE html>\n"
  tag("html", { :lang => I18n.locale.to_s }, :none) do
    tag("head", {}, :head) do
      tag("meta", { :charset => "utf-8" }, :charset)
      tag("meta", { :name => "viewport", :content => "width=device-width, initial-scale=1" }, :viewport)
      tag("title", {}, :title) { text full_title }
      param(:stylesheets) do
        # The theme's own first, then the application's, so an application can
        # override what the theme said. **Which** stylesheets the theme has is
        # the theme's business: it registers them, and a theme with none -- or
        # no theme at all -- simply adds nothing here.
        HoboRapid::Theme.stylesheets.each_with_index do |sheet, i|
          call_tag(:stylesheet, { :name => sheet }, :as => :"theme_stylesheet_#{i}")
        end
        # And the plugins', between the theme and the application: a plugin can
        # override the theme and the application can override both.
        (defined?(Hobo) ? Hobo.brought[:stylesheets] : []).each do |sheet|
          call_tag(:stylesheet, { :name => sheet }, :as => :"plugin_stylesheet_#{sheet}")
        end
        call_tag(:stylesheet, { :name => subsite || "application" }, :as => :app_stylesheet)
      end
      unless attributes[:bottom_load_javascript]
        param(:scripts) { call_tag(:import_map, { :name => subsite || "application" }, :as => :application_javascript) }
      end
      raw csrf_meta_tag.to_s
    end

    tag("body", {}, :body) do
      # `<nav>` and `<header>` are real elements now: the old theme painted
      # `<div class="navbar">` because it predates HTML5.
      # `bg-body-tertiary` is not decoration: a Bootstrap 5 navbar is
      # **transparent** unless it is told otherwise, so the bar came out white
      # on white and the application looked like it had no chrome at all. The
      # old theme got it from `navbar-inner`, which Bootstrap 5 dropped.
      tag("nav", { :class => "navbar" }, :navbar) do
        tag("div", { :class => "navbar-inner" }, :navbar_container) do
          tag("div", {}, :app_name) do
            tag("a", { :class => "brand", :href => "#{base_url}/" }) { call_tag(:app_name, {}, :as => :app_name_link) }
          end
          if nav_location.blank? || nav_location == "top"
            call_tag(:main_nav, { :class => "nav main-nav", :current => attributes[:title] }, :as => :main_nav)
          end
          # The search box goes **inside** the account bar, not beside it: that
          # is where Hobo 2 put it, and it is the place an application knows how
          # to take it away from, with `<search: replace/>`. And only with the
          # bar on top, which is what `include-search` decided.
          call_tag(:account_nav, { :include_search => nav_location.blank? || nav_location == "top" },
                   :as => :account_nav)
        end
      end

      if nav_location == "sub"
        tag("div", { :class => "container" }, :nav_container) do
          tag("nav", { :class => "subnav" }, :subnav) do
            call_tag(:main_nav, { :class => "nav subnav-list", :current => attributes[:title] }, :as => :sub_nav)
          end
        end
      end

      tag("div", { :class => "container" }, :container) do
        call_tag(:flash_messages, {}, :as => :flash)

        tag("div", { :class => "columns" }, :main_row) do
          aside.call if has_aside && aside_location == "left"

          # Cada hueco con el nombre de su papel puesto.
          #
          # Estos cuatro se pintaban sin clase ninguna, y el nombre del papel se
          # quedaba dentro: sólo lo sabía quien leyera el código del tema. Desde
          # fuera es lo contrario de lo que hace falta -- una aplicación
          # **escribe css contra estos sitios**, que son los cuatro huecos donde
          # va todo, y `<header>` a secas no se puede seleccionar sin alcanzar
          # también las cabeceras de dentro.
          #
          # Son los mismos nombres que ponía Hobo 2, y por eso una hoja traída
          # de allí --`.content-header h2 {margin:0}` de amenti-- vuelve a
          # aplicar sin tocarla. Que coincidan no es nostalgia: el papel es el
          # mismo y el nombre ya estaba elegido.
          tag("div", { :class => "content content-#{content_size}" }, :main_column) do
            tag("section", { :class => "content-inner" }, :content) do
              tag("section", { :class => "main-content" }, :main_content) do
                # Vacia no se pinta. El tema la viste de tarjeta --con fondo y
                # borde, porque una cabecera de contenido lo lleva-- y una
                # pagina que no la usa se quedaba con una caja gris flotando
                # encima de todo. Las paginas derivadas pintan la suya **dentro**
                # del cuerpo, asi que salian las dos: la de verdad y el hueco.
                if all_parameters.keys.any? { |name| name.to_s.end_with?("content_header") }
                  tag("header", { :class => "content-header" }, :content_header)
                end
                tag("section", { :class => "content-body" }, :content_body)
              end
            end
          end

          aside.call if has_aside && aside_location == "right"
        end
      end

      # `footer`, which is what it is called in Hobo 2 and what everybody
      # writes. It was called `page_footer`, so a `<footer:>` from an old
      # template reached nowhere and the footer came out empty.
      tag("footer", { :class => "page-footer" }, :footer)
      param(:page_scripts)
      if attributes[:bottom_load_javascript]
        param(:bottom_scripts) { call_tag(:import_map, { :name => subsite || "application" }, :as => :bottom_javascript) }
      end
    end
  end
end

# The pieces a page leans on, plain enough that an application can replace any
# of them without the page noticing.
Rapid.define(:app_name) { text app_name }
Rapid.define(:stylesheet, :attrs => [:name]) do
  href = asset_path_for(attributes[:name], "css")
  tag("link", { :rel => "stylesheet", :href => href }) if href
end

# The page's own JavaScript: the import map, the preloads and the one line that
# imports the entry point.
#
# An application built with import maps does not load its JavaScript with a
# `<script src>`: the entry point is an ES module and it needs the map to
# resolve its bare imports. A plain tag pulled `application.js` in as a classic
# script, which dies on its first `import` -- so **on every page Hobo painted,
# not one line of the application's JavaScript ran**, Stimulus included. The
# pages Rails renders were fine, which is why it went unseen: they go through
# the layout, and the layout says `javascript_importmap_tags`.
#
# It is **its own tag, and the page calls it once**. It used to be `<javascript>`
# doing double duty, and then any template that said `<javascript name="algo"/>`
# in its `<head:>` -- which is how Hobo 2 pulled in a plain file -- printed the
# whole import map a second time. Two maps in one head is two module registries:
# amenti's page came with every Stimulus controller declared twice.
Rapid.define(:import_map, :attrs => [:name]) do
  helpers = defined?(ActionController::Base) ? ActionController::Base.helpers : nil

  unless helpers.respond_to?(:javascript_importmap_tags)
    # Without importmap-rails there is nothing to resolve and the plain script
    # is the right answer.
    src = asset_path_for(attributes[:name], "js")
    next tag("script", { :src => src, :defer => true }) if src
    next
  end

  entry = attributes[:name].to_s
  entry = "application" unless HoboRapid.pinned?(entry)
  raw helpers.javascript_importmap_tags(entry)

  # And whatever carries the behaviour, when it is not Stimulus.
  #
  # With Stimulus there is nothing to say: the application does
  # `eagerLoadControllersFrom("controllers")` and its controllers load
  # themselves. Anything else -- `hobo_jquery` -- is a module nobody imports, so
  # it is imported here. One line, and only when there is another.
  modules = []
  if defined?(Hobo)
    modules << Hobo.behaviours[Hobo.behaviour_in_use]&.dig(:javascript)
    # And any other plugin that brings javascript of its own.
    modules.concat(Hobo.brought[:javascript])
  end
  modules.compact.uniq.each do |mod|
    raw %(<script type="module">import "#{mod}"</script>)
  end
end

# `<javascript name="cookieconsent"/>`: **one named file**, which is all this
# ever meant. The mirror of `<stylesheet>`, and the two are written side by side
# in every old `<head:>` in existence.
#
# A name the import map knows is imported as a module -- a bare `<script src>`
# on a file full of `import` does nothing but throw. Anything else is the plain
# script it has always been.
Rapid.define(:javascript, :attrs => [:name]) do
  name = attributes[:name].to_s

  if HoboRapid.pinned?(name)
    raw %(<script type="module">import "#{name}"</script>)
  else
    src = asset_path_for(name, "js")
    tag("script", { :src => src, :defer => true }) if src
  end
end
# The navigation is not written anywhere either: it is the models that have an
# index page. A menu somebody has to keep in step with the application is a menu
# that goes out of date the first week.
Rapid.define(:main_nav, :attrs => [:current, :class]) do
  tag("ul", { :class => attributes[:class] || "navbar-nav" }, :items) do
    HoboRapid.navigable_models.each do |model, path|
      # Como se llama el modelo **en el idioma de la aplicación**. Todo lo demás
      # de la página pasa por aquí -- el título, el «8 libros», las columnas --
      # y solo la barra seguía diciendo «Books» en una aplicación en castellano,
      # porque humanizaba el nombre de la clase en vez de preguntar.
      label = if model.respond_to?(:model_name)
                model.model_name.human(:count => 2)
              else
                model.name.demodulize.underscore.humanize.pluralize
              end
      current = { :class => "nav-link current", :"aria-current" => "page" } if label == attributes[:current]

      tag("li", { :class => "nav-item" }, :"#{model.name.demodulize.underscore}_item") do
        tag("a", { :class => "nav-link", :href => path }.merge(current || {})) { text label }
      end
    end
  end
end

# The right-hand side of the bar. What goes in it is RAPID's (piece 13a): that
# an application says who you are and lets you stop being them is not a matter
# of taste. This decides where it sits and what it looks like.
Rapid.define(:account_nav, :attrs => [:include_search]) do
  tag("ul", { :class => "nav account-nav" }, :items) do
    # The search box, with a param of its own and in its own `<li>`: `<search:
    # replace/>` is how it is taken away, and it is what applications that do
    # not want it write. It used to sit outside the bar, and that `<search:>`
    # found nothing there to take away.
    if attributes[:include_search]
      tag("li", { :class => "nav-item site-search-item" }, :search) do
        call_tag(:search_box, {}, :as => :search_box)
      end
    end

    param(:session_links) do
      tag("li", { :class => "nav-item" }, :dev_user_changer) do
        call_tag(:dev_user_changer, {}, :as => :changer)
      end
      # `merge_params`: whatever `<account-nav>` is given that is not its own
      # goes down here.
      #
      # The names an old template brings -- `sign-up:`, `log-in:`,
      # `logged-in-as:` -- belong to these links, and in Hobo 2 they were
      # written on `<account-nav>` because there was nothing in between. Without
      # handing them down, `<sign-up: replace/>` took nothing away.
      call_tag(:session_links, {}, :as => :links, :merge_params => true)
    end
  end
end

module HoboRapid

  # Whether the application's import map knows this entry point. A subsite that
  # has no JavaScript of its own would otherwise ask for a module nobody pinned,
  # and importmap-rails raises rather than shrug.
  def self.pinned?(name)
    return false if name.to_s.empty?
    return false unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
    map = Rails.application.try(:importmap)
    !!map&.packages&.key?(name.to_s)
  rescue StandardError
    false
  end

  # The models a person can actually navigate to: the ones with an index route.
  # Asking the routes rather than keeping a list is what stops the menu drifting
  # away from the application.
  def self.navigable_models
    return [] unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
    return [] unless defined?(Hobo::Model)

    helpers = Rails.application.routes.url_helpers
    Hobo::Model.all_models.filter_map do |model|
      path = begin
               helpers.polymorphic_path(model)
             rescue StandardError
               nil
             end
      [model, path] if path
    end.sort_by { |model, _| model.name }
  end

end

# --- the bar, written by hand (piece 13a, finished 2026-08-11) ----------------
#
# `<main-nav>` builds the bar from the models that have a page, which is what a
# new application wants. These two are the other half: the bar written item by
# item, which is what an application writes when the order matters, or when a
# dropdown goes in the middle, or when one entry is not a model at all.
#
# They were in **the theme** in Hobo 2 -- `hobo_clean/taglibs/nav.dryml` -- and
# that was the design error decision 13a names: with the nav in the theme,
# changing theme changed which tags existed, and a template written for one
# would not compile under another. The nav is not a matter of taste.

# `current="Inicio"` says which entry you are looking at. It is **declared**, so
# that it goes into the scope and not into the markup: undeclared, it went
# straight through `all_attributes` and the bar came out as
# `<ul current="Inicio">`, an attribute no browser has ever heard of.
Rapid.define(:navigation, :attrs => [:class, :current]) do
  tag("ul", extra_attributes.merge(:class => ["nav", attributes[:class]].compact.join(" ")), :items) do
    with_scope(:current_navigation => attributes[:current]) { param(:default) }
  end
end

# `<nav-item with="&Expediente">Expedientes</nav-item>`
#
# The url comes from what it is painting -- a model goes to its index -- or from
# `href`. With no content it says the name of the model, which is what made the
# bar one line per entry.
Rapid.define(:nav_item, :attrs => [:href, :current]) do
  target = attributes[:href] || path_for(this)
  next if target.nil?

  here = attributes[:current] || (HoboRapid.query_parameters["__path"].to_s == target)
  classes = ["nav-item", ("current" if here)].compact.join(" ")

  tag("li", { "class" => classes }, :item) do
    tag("a", { "href" => target, "class" => "nav-link" }, :link) do
      param(:default) do
        model = this.is_a?(Module) ? this : this.class
        text HoboRapid::Derivation.plural_of(model)
      end
    end
  end
end

# One transition of a lifecycle, as a button. `<transition-buttons>` paints them
# all; this is the one an application names when it wants a single one
# somewhere of its own.
Rapid.define(:transition_button, :attrs => [:transition, :label]) do
  call_tag(:transition_link, all_attributes, :as => :button)
end
