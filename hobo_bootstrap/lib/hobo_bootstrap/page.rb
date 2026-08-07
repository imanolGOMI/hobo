# The theme: piece 13b.
#
# `<page>` is the contract between Hobo and a theme, and it is the reason the
# param mechanism of layer 3 had to survive: ~30 named extension points, so an
# application can change one corner of a page without owning the whole thing.
#
# The markup is Bootstrap 5. What was here targeted `bootstrap-sass ~> 2.1` --
# Bootstrap 2.1, from 2012 -- and its classes (`navbar-inner`, `nav-collapse`,
# `span9`, `icon-bar`) have not existed since Bootstrap 3. The *contract* is
# what carries over; the class names are the cheap part.
#
# The aside sizing used Bootstrap 2's twelve `spanN` classes. Bootstrap 5 says
# the same thing with `col-*`, so `content_size` and `aside_size` keep their
# meaning -- twelfths -- and only the spelling changes.

require "rapid"
require "hobo_rapid/tags/structure"

module HoboBootstrap

  module PageSupport

    def app_name = "Hobo"
    def subsite = nil
    def base_url = ""
    def csrf_meta_tag = nil

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

Rapid::Tag.include(HoboBootstrap::PageSupport)

Rapid.define(:page, :attrs => [:title, :full_title, :nav_location, :aside_location,
                               :content_size, :aside_size, :bottom_load_javascript]) do
  full_title = attributes[:full_title] || [attributes[:title], app_name].compact.join(" : ")
  has_aside = !all_parameters[:aside].nil?

  content_size = (attributes[:content_size] || (has_aside ? 9 : 12)).to_i
  aside_size = (attributes[:aside_size] || (12 - content_size)).to_i
  aside_location = attributes[:aside_location] || "right"
  nav_location = attributes[:nav_location]

  aside = proc do
    tag("div", { :class => "col-#{aside_size}" }, :aside_column) do
      tag("aside", { :class => "card p-3" }, :aside)
    end
  end

  raw "<!DOCTYPE html>\n"
  tag("html", { :lang => I18n.locale.to_s }, :none) do
    tag("head", {}, :head) do
      tag("meta", { :charset => "utf-8" }, :charset)
      tag("meta", { :name => "viewport", :content => "width=device-width, initial-scale=1" }, :viewport)
      tag("title", {}, :title) { text full_title }
      param(:stylesheets) do
        # Bootstrap first, then what Hobo adds, then the application's own, so
        # each one can override the one before it.
        call_tag(:stylesheet, { :name => "bootstrap" }, :as => :bootstrap_stylesheet)
        call_tag(:stylesheet, { :name => "hobo" }, :as => :hobo_stylesheet)
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
      tag("nav", { :class => "navbar navbar-expand-lg" }, :navbar) do
        tag("div", { :class => "container" }, :navbar_container) do
          tag("div", {}, :app_name) do
            tag("a", { :class => "navbar-brand", :href => "#{base_url}/" }) { call_tag(:app_name, {}, :as => :app_name_link) }
          end
          if nav_location.blank? || nav_location == "top"
            call_tag(:main_nav, { :class => "navbar-nav", :current => attributes[:title] }, :as => :main_nav)
          end
          call_tag(:account_nav, {}, :as => :account_nav)
        end
      end

      if nav_location == "sub"
        tag("div", { :class => "container" }, :nav_container) do
          tag("nav", { :class => "subnav" }, :subnav) do
            call_tag(:main_nav, { :class => "nav nav-pills", :current => attributes[:title] }, :as => :sub_nav)
          end
        end
      end

      tag("div", { :class => "container" }, :container) do
        call_tag(:flash_messages, {}, :as => :flash)

        tag("div", { :class => "row" }, :main_row) do
          aside.call if has_aside && aside_location == "left"

          tag("div", { :class => "col-#{content_size}" }, :main_column) do
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

Rapid.define(:javascript, :attrs => [:name]) do
  src = asset_path_for(attributes[:name], "js")
  tag("script", { :src => src, :defer => true }) if src
end
Rapid.define(:main_nav, :attrs => [:current, :class]) { tag("ul", { :class => attributes[:class] }, :items) }
Rapid.define(:account_nav) { tag("ul", { :class => "navbar-nav ms-auto" }, :items) }
