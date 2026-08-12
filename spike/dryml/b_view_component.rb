# Spike B -- the same four DRYML properties on ViewComponent + ERB.
#
# NOT RUNNABLE STANDALONE. ViewComponent 4.1 cannot be required without a booted
# Rails application, which is itself the first data point: spike A runs with
# `ruby a_ruby_dsl.rb` and no dependencies at all.
#
# What follows is the shape the code would take, and where each DRYML property
# either maps cleanly or does not map.

# --- 1. `param` -> slots ------------------------------------------------------
#
# DRYML declares an extension point inline, anywhere in the markup:
#
#     <div class="navbar" param="navbar">
#       <header class="container" param>
#         <div param="app-name">...</div>
#       </header>
#     </div>
#
# ViewComponent needs every slot declared up front, in Ruby:

class PageComponent < ViewComponent::Base
  renders_one :head
  renders_one :navbar
  renders_one :header
  renders_one :app_name
  renders_one :container
  renders_one :content
  renders_one :page_footer
  # ...and the other 23 params of hobo_bootstrap's <page>

  def initialize(title:, nav_location: "top")
    @title = title
    @nav_location = nav_location
  end
end

# page_component.html.erb
#
#     <html>
#       <body>
#         <div class="navbar">
#           <%= navbar %>
#           <header class="container"><%= app_name %></header>
#         </div>
#         <div class="container"><%= content %></div>
#       </body>
#     </html>
#
# Three things do not carry over:
#
#   a) A slot is *declared in Ruby*, so a theme cannot introduce a param the
#      base component did not already declare. In DRYML `param` is just an
#      attribute on any element, which is what makes a theme's contract open.
#
#   b) Slots do not nest. `<header param>` containing `<div param="app-name">`
#      is two extension points, one inside the other, and the outer one has to
#      keep working when the inner is overridden. Slots are a flat list.
#
#   c) A slot is *replace only*. There is no <old-x>: a caller cannot wrap the
#      default, because the default is written in the template and is discarded
#      the moment the slot is given. That is precisely the failure mode of the
#      first attempt, recorded in HALLAZGOS.md: `replace` silently drops
#      whatever was underneath.


# --- 2. `<extend>` -> no equivalent -------------------------------------------
#
# DRYML:
#
#     <extend tag="page">
#       <old-page merge nav-location="sub"/>
#     </extend>
#
# The nearest ViewComponent shape is a subclass:

class ThemedPageComponent < PageComponent
  def initialize(**options)
    super(**options.reverse_merge(:nav_location => "sub"))
  end
end

# But that is not the same thing. Everything already written refers to
# `PageComponent`, and keeps rendering the unthemed one. To make an extension
# reach existing callers you need a name-to-class registry with late lookup --
# at which point you have rebuilt the tag registry of spike A anyway, and
# `Module#prepend` would have given you `super` for free.


# --- 3. polymorphic dispatch -> no equivalent ---------------------------------
#
# DRYML dispatches on the type of the value being rendered:
#
#     <def tag="view" for="Date"><%= this.strftime("%d/%m/%Y") %></def>
#
# ViewComponent has `renders_one :thing, types: {...}`, which chooses among
# *slot* variants the caller names explicitly. It does not look at the type of a
# value. This has to be written by hand either way: a registry keyed by class,
# walking ancestors. Roughly the ten lines of `polymorphic_lookup` in spike A.


# --- 4. the implicit `this` ---------------------------------------------------
#
# Every component takes explicit constructor arguments, which is ViewComponent's
# whole point. `<view:name/>` becomes something like
# `render(ViewComponent.new(value: record.name))`.
#
# That is the readable choice for hand-written components, and the wrong one for
# *generated* markup: the derivation engine emits markup for fields it discovers
# at runtime, and an implicit context is what keeps that short. It also drops the
# updater's automatic conversion rate, since `this` at any point is a runtime
# property, not a static one.
