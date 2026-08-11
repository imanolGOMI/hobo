require "rapid"

module HoboRapid

  # How a derived page is retouched **from the view**, which is what DRYML did
  # in Hobo 2 and what had been lost in the port.
  #
  # The whole mechanism -- the params, the four insertion points, the
  # replacement -- was there since layer 3. What was missing was writing it
  # short. This:
  #
  #   <%= rapid_tag :index_page, @books,
  #         :append_heading => Rapid.markup { text " — La Biblioteca" } %>
  #
  # is written like this:
  #
  #   <% append_heading " — La Biblioteca" %>
  #
  # Without naming the page, because **the controller already knows which one it
  # is**: a view is an action and an action paints a page. In DRYML you had to
  # open `<index-page>` even to touch only the title; here you do not.
  #
  # ## The grammar, which is the DRYML manual's
  #
  # (`doc/manual/dryml-guide.markdown`, "Inserting extra content" and "Replacing
  # a parameter entirely"). Seven things, not four:
  #
  #   <heading:>x</heading:>          param :heading, "x"       the content
  #   <heading: class="big"/>         param :heading, class: …  the attributes
  #   <heading: replace>x</heading:>  replace :heading do … end the whole element
  #   <page without-heading/>         without :heading          take it away
  #   <before-heading:>               before_heading
  #   <prepend-heading:>              prepend_heading
  #   <append-heading:>               append_heading
  #   <after-heading:>                after_heading
  #   <param-content for="heading"/>  param_content             what it would paint
  #
  # With a string when it is one line and with a block when there is markup,
  # which is the equivalent of opening and closing the tag:
  #
  #   <% before_heading do %><p>Catalogue</p><% end %>
  #
  # ## Why `param :heading` and not `heading`
  #
  # The four insertion points are recognised by their prefix, and that is why
  # they can be written as they are: no view method begins with `before_`,
  # `prepend_`, `append_` or `after_`. A bare name cannot be recognised:
  # `heading` could be a param, an application helper or a typo, and taking it
  # blindly would turn every typo into a param that does not exist and does not
  # complain. The names of the params are not known until the page is painted,
  # which is after the view declares them, so there is no way to check. An
  # explicit verb costs five letters and does not lie.
  #
  # ## And the rule, which is Hobo 2's
  #
  # If the view **only declares params**, the page is still the derived one and
  # this retouches it. If the view **writes markup**, the page is yours and it
  # replaces the derived one -- exactly what happened when you wrote an
  # `index.dryml`. Both at once is a contradiction, and the controller says so
  # out loud rather than choosing on its own.
  module Params

    # The four insertion points of the manual. No html attribute begins like
    # this, which is why they can be recognised by name.
    PSEUDO = /\A(before|prepend|append|after)_(\w+)\z/

    # What the view has declared. It lives on the **controller** and not on the
    # view: `render_to_string` builds a fresh view context, so a view that kept
    # this on itself would lose what it declared before anybody read it.
    def hobo_declared_params
      # Inside a taglib's `extend_tag`, the same verbs declare the params **of
      # that tag**: `<% append_heading %>` in the taglib retouches every page,
      # and in a view it retouches its own. That is the rule DRYML had, where
      # `<append-heading:>` was written the same in `application.dryml` as in
      # the page.
      from_taglib = HoboRapid::Taglib.declared_params if defined?(HoboRapid::Taglib)
      return from_taglib if from_taglib

      owner = respond_to?(:controller) && controller ? controller : self
      owner.instance_variable_get(:@hobo_declared_params) ||
        owner.instance_variable_set(:@hobo_declared_params, {})
    end

    # `<heading:>x</heading:>` and its variants.
    #
    #   param :heading, "My books"        the content
    #   param :heading, class: "big"      the attributes only
    #   param :heading do … end           the content, with markup
    #
    # The name is the param's, and it goes first because it is what is being
    # touched.
    def param(name, *args, **attributes, &block)
      hobo_param(name, *args, **attributes, &block)
    end

    # `<heading: replace>x</heading:>`: the whole element, not its content. With
    # `param_content` inside, what was there is wrapped rather than thrown away.
    def replace(name, *args, **attributes, &block)
      hobo_param(name, :replace, *args, **attributes, &block)
    end

    def hobo_param(name, *args, **attributes, &block)
      replace = args.delete(:replace) ? true : false
      string = args.first

      # The block is kept **unrun**, and runs when the page paints it. Capturing
      # here would be simpler and would break `param_content`: what that returns
      # only exists while the tag is being painted, and at declaration time
      # there is no page yet.
      view = self
      content = if block
                  proc { raw view.hobo_capture(&block) }
                elsif string
                  proc { raw ERB::Util.html_escape(string) }
                end

      hobo_declared_params[name.to_sym] =
        Rapid.parameter(:attributes => attributes, :replace => replace, &content)
      nil
    end

    # `<page without-heading/>`: a replacement with no content, which is how the
    # manual defines it.
    def without(*names)
      names.each { |name| hobo_declared_params[name.to_sym] = Rapid.parameter(:replace => true) }
      nil
    end

    # The headings of a list's table, each a link that sorts by that column.
    #
    #   <% extend_tag :index_page do %>
    #     <% sortable_headings %>
    #     <%= old %>
    #   <% end %>
    #
    # A verb and not a tag because what it does is declare params -- one per
    # column -- which is exactly what everything else in this file does.
    #
    # Here and not in the application because sorting a table is nobody's design
    # decision: it is what `<table-plus>` did in Hobo 2, and a list of eight
    # columns you cannot sort by is half a list. The controller already reads
    # `?sort=` (find_or_paginate), so this only puts the links that lead to what
    # already works.
    def sortable_headings(*only)
      records = Rapid::Context.this
      model = records.respond_to?(:klass) ? records.klass : Array(records).first&.class
      return nil unless model.respond_to?(:column_names)

      columns = only.presence || HoboRapid::Derivation.index_columns(model)
      sorted_by = HoboRapid.query_parameters["sort"].to_s

      columns.each do |field|
        # Real columns only: `category` is an association, and an association
        # cannot be handed to an ORDER BY. A heading that does not sort is worse
        # than a heading of plain text.
        next unless model.column_names.include?(field.to_s)

        label = HoboRapid::Derivation.label_for(model, field)
        # Already sorting by this one and upwards: the next click turns it over.
        ascending = sorted_by == field.to_s
        arrow = if sorted_by.delete_prefix("-") == field.to_s
                  ascending ? " ↑" : " ↓"
                else
                  ""
                end
        target = HoboRapid.query_parameters.merge("sort" => "#{"-" if ascending}#{field}")

        hobo_declared_params[:"#{field}_heading"] ||= Rapid.parameter do
          tag("a", { :href => "?#{target.to_query}", :class => "sort-link" }) { text "#{label}#{arrow}" }
        end
      end
      nil
    end

    # `<param-content for="heading"/>`: what the page was going to paint there.
    #
    # It is the tag runtime's `old`, and it is for **wrapping without
    # duplicating**:
    #
    #   <% param :heading do %><a href="…"><%= param_content %></a><% end %>
    #
    # With this, the limitation Hobo 2 documented also goes away -- `before` and
    # `after` on the same param at once --: it is a replacement with a
    # `param_content` in the middle.
    #
    # It returns a **string**, and that is not a detail: inside a view block the
    # one writing is ActionView's buffer, not Rapid's. Painting it directly
    # would send it to the wrong buffer and it would come out somewhere else on
    # the page.
    def param_content
      stack = Rapid::Context.old_stack
      return "".html_safe if stack.nil? || stack.empty?

      painted = Rapid::Context.capture do
        Rapid::Context.with(:old_stack => stack[0..-2]) { stack.last&.call }
      end
      painted.to_s.html_safe
    end

    def method_missing(name, *args, **attributes, &block)
      return super unless name.to_s.match?(PSEUDO)
      hobo_param(name, *args, **attributes, &block)
    end

    def respond_to_missing?(name, include_private = false)
      name.to_s.match?(PSEUDO) || super
    end

    # The markup the block writes. In a view ActionView captures it; in a test,
    # outside Rails, the block returns its text and that is that.
    def hobo_capture(&block)
      return capture(&block) if respond_to?(:capture)
      block.call.to_s
    end

  end

end
