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

    # El nombre de la aplicación, que es el de la aplicación y no el de la
    # herramienta: la barra de `hobo3_mi_app` decía «Hobo». Lo sabe Rails, y el
    # controlador de la portada ya lo pasaba a mano -- lo que faltaba era que
    # las páginas derivadas, que no pasan nada, lo tuvieran también.
    def app_name
      return "Hobo" unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      Rails.application.class.module_parent_name.titleize
    rescue StandardError
      "Hobo"
    end
    def subsite = nil
    def base_url = ""
    # El token de Rails, en la cabecera de la pagina.
    #
    # Estaba a `nil` -- un hueco que nunca se lleno -- y no se notaba porque los
    # formularios llevan el suyo en un campo oculto. Lo que no funciona sin esto
    # es **cualquier POST desde javascript**: no hay de donde sacar el token y
    # Rails contesta 422. Lo encontro `sortable-collection` al guardar el orden
    # nuevo, que es exactamente ese caso.
    #
    # El token ya viaja: `rapid_tag` lo deja en HoboRapid para el resto del
    # render, porque los formularios tambien lo necesitan.
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
  full_title = attributes[:full_title] || [attributes[:title], app_name].compact.join(" : ")
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
        # Y las de los plugins, entre el tema y la aplicacion: un plugin puede
        # pisar al tema y la aplicacion puede pisarlos a los dos.
        (defined?(Hobo) ? Hobo.brought[:stylesheets] : []).each do |sheet|
          call_tag(:stylesheet, { :name => sheet }, :as => :"plugin_stylesheet_#{sheet}")
        end
        call_tag(:stylesheet, { :name => subsite || "application" }, :as => :app_stylesheet)
      end
      unless attributes[:bottom_load_javascript]
        param(:scripts) { call_tag(:javascript, { :name => subsite || "application" }, :as => :application_javascript) }
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
          call_tag(:search_box, {}, :as => :search_box)
          call_tag(:account_nav, {}, :as => :account_nav)
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

          tag("div", { :class => "content content-#{content_size}" }, :main_column) do
            tag("section", {}, :content) do
              tag("section", {}, :main_content) do
                tag("header", {}, :content_header)
                tag("section", {}, :content_body)
              end
            end
          end

          aside.call if has_aside && aside_location == "right"
        end
      end

      tag("footer", { :class => "page-footer" }, :page_footer)
      param(:page_scripts)
      if attributes[:bottom_load_javascript]
        param(:bottom_scripts) { call_tag(:javascript, { :name => subsite || "application" }, :as => :bottom_javascript) }
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

# An application built with import maps does not load its JavaScript with a
# `<script src>`: the entry point is an ES module and it needs the map to
# resolve its bare imports. A plain tag pulled `application.js` in as a classic
# script, which dies on its first `import` -- so **on every page Hobo painted,
# not one line of the application's JavaScript ran**, Stimulus included. The
# pages Rails renders were fine, which is why it went unseen: they go through
# the layout, and the layout says `javascript_importmap_tags`.
#
# Without importmap-rails there is nothing to resolve and the plain tag is
# right, so both are kept.
Rapid.define(:javascript, :attrs => [:name]) do
  helpers = defined?(ActionController::Base) ? ActionController::Base.helpers : nil

  if helpers.respond_to?(:javascript_importmap_tags)
    entry = attributes[:name].to_s
    entry = "application" unless HoboRapid.pinned?(entry)
    raw helpers.javascript_importmap_tags(entry)

    # Y quien lleve el comportamiento, si no es Stimulus.
    #
    # Con Stimulus no hace falta decir nada: la aplicacion hace
    # `eagerLoadControllersFrom("controllers")` y sus controladores se cargan
    # solos. Cualquier otro -- `hobo_jquery` -- es un modulo que nadie importa,
    # asi que se importa aqui. Una linea, y solo cuando hay otro.
    modulos = []
    if defined?(Hobo)
      modulos << Hobo.behaviours[Hobo.behaviour_in_use]&.dig(:javascript)
      # Y el de cualquier otro plugin que traiga javascript propio.
      modulos.concat(Hobo.brought[:javascript])
    end
    modulos.compact.uniq.each do |modulo|
      raw %(<script type="module">import "#{modulo}"</script>)
    end
  else
    src = asset_path_for(attributes[:name], "js")
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
Rapid.define(:account_nav) do
  tag("ul", { :class => "nav account-nav" }, :items) do
    param(:session_links) do
      tag("li", { :class => "nav-item" }, :dev_user_changer) do
        call_tag(:dev_user_changer, {}, :as => :changer)
      end
      call_tag(:session_links, {}, :as => :links)
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
