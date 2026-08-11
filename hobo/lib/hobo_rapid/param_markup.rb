# The params of DRYML, written as markup, in **any** template language.
#
#   <%# app/views/books/index.html.erb %>
#   <append-heading:><%= " — La Biblioteca" %></append-heading:>
#   <heading: class="big"/>
#
# The same thing `<% append_heading %>` does, written the way it was written in
# Hobo 2. Both work; this is the one that reads like the page it is changing.
#
# ## Why this can be done to ERB and a whole language cannot
#
# `<append-heading:>` **is not valid html and cannot appear by accident**. A
# name with a colon and nothing after it is not an element, not an xml
# namespace (`<svg:rect>` has a name after the colon) and not anything a
# template of somebody else's would contain. So this pass can rewrite those and
# **leave every other byte of the file alone** -- which is what makes it safe on
# `.html.erb`, where compiling the whole file as markup would change what every
# `<div>` in the application means.
#
# What comes out is ERB again, so what is inside a param stays exactly as it
# was: `<%= %>`, helpers, partials, all of it.
#
#   <append-heading:>x</append-heading:>   ->  <% append_heading do %>x<% end %>
#   <heading:>x</heading:>                 ->  <% param :heading do %>x<% end %>
#   <heading: replace>x</heading:>         ->  <% replace :heading do %>x<% end %>
#   <heading: class="big"/>                ->  <% param :heading, "class" => "big" %>
#   <page without-heading/>                ->  <% without :heading %>
#
# ## And it is not for ERB
#
# It runs on the source before the template handler sees it, so it works the
# same in Slim or HAML: the handler that gets the transformed source is
# whichever one that file already had.

module HoboRapid

  module ParamMarkup

    # `<name:>`, `<name: attrs>`, `<name:/>`, `</name:>`.
    #
    # The colon has to be followed by whitespace, `>` or `/`: that is what tells
    # `<heading:>` from `<svg:rect>`, and it is the whole reason this is safe to
    # run over a file nobody wrote for Hobo.
    OPEN = /<([A-Za-z_][\w-]*):(?=[\s\/>])([^>]*?)(\/?)>/
    CLOSE = %r{</([A-Za-z_][\w-]*):\s*>}

    # The four insertion points, which take a block and no name.
    PSEUDO = /\A(before|prepend|append|after)_/

    # A call to a tag: `<field-list fields="a, b"/>`, `<card>…</card>`.
    #
    # Only names **with a hyphen**, and only names Hobo has a tag for. Both
    # halves of that matter:
    #
    # A hyphen, because `<card>` with no hyphen cannot be told from an element
    # nobody has heard of, and a template that writes `<card>` meaning html
    # would silently start calling a tag.
    #
    # And a tag Hobo knows, because a hyphen is exactly what a **web component**
    # has -- `<ion-button>`, `<my-widget>` -- and those are real elements the
    # browser respects. Rewriting every hyphenated name would break any
    # application using one.
    #
    # Which leaves the case where an application has a web component named the
    # same as a Hobo tag. Then Hobo's wins, and that is the right way round: it
    # is the application's own template, in an application that chose Hobo.
    TAG = /<([A-Za-z_][\w]*(?:-[\w]+)+)((?:\s[^>]*?)?)(\/?)>/
    TAG_CLOSE = %r{</([A-Za-z_][\w]*(?:-[\w]+)+)\s*>}

    class << self

      # Whose template it is. Only the application's own are rewritten.
      #
      # A gem ships views as well, and rewriting somebody else's file is going
      # into their house: whatever rule this pass follows, they never agreed to
      # it. Inside `app/views` the rule is the application's to accept, and it
      # accepted it by using Hobo.
      def ours?(template)
        return true unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

        path = template.respond_to?(:identifier) ? template.identifier.to_s : ""
        path.start_with?(Rails.root.join("app").to_s)
      end

      def transform(source)
        return source unless source.include?("<")

        written = source.gsub(CLOSE) { "<% end %>" }
                        .gsub(OPEN) { opening(Regexp.last_match) }

        written.gsub(TAG_CLOSE) { |whole| known?(Regexp.last_match[1]) ? "<% end %>" : whole }
               .gsub(TAG) { |whole| tag_call(Regexp.last_match) || whole }
      end

      # Whether Hobo has a tag with that name **right now**.
      #
      # Asked while the template compiles, which in an application is on the
      # first request -- by then the catalogue and the taglibs are loaded, so
      # the answer is settled. It is not settled in a bare process that has
      # loaded half of Rapid, and that is a thing to know before writing a test
      # that compiles templates without an application around them.
      def known?(name)
        return false unless defined?(Rapid)
        Rapid.tags.key?(name.tr("-", "_").to_sym)
      end

      def tag_call(match)
        name = match[1]
        return nil unless known?(name)

        ruby = "#{name.tr("-", "_")}#{arguments(match[2])}"
        match[3].empty? ? "<%= #{ruby} do %>" : "<%= #{ruby} %>"
      end

      def arguments(attributes)
        pairs = pairs_of(attributes)
        pairs.empty? ? "" : "(#{pairs})"
      end

      private

      def opening(match)
        name = match[1].tr("-", "_")
        attributes = match[2].to_s.strip
        closed = !match[3].to_s.empty?

        verb, rest = verb_for(name, attributes)
        return "<% #{verb}#{rest} %>" if closed

        "<% #{verb}#{rest} do %>"
      end

      def verb_for(name, attributes)
        replace = attributes.sub!(/(\A|\s)replace(\s|\z)/, " ") ? "replace" : nil
        pairs = pairs_of(attributes)

        if name.match?(PSEUDO) && replace.nil?
          # `append_heading` names the param in the verb, so nothing else is
          # needed -- which is what made it short in DRYML too.
          [name, pairs.empty? ? "" : ", #{pairs}"]
        else
          [replace || "param", [" :#{name}", pairs.empty? ? nil : pairs].compact.join(", ")]
        end
      end

      # `class="big" fields="a, b"` -> `:class => "big", :fields => "a, b"`, and
      # `&expr` is Ruby, the same as everywhere else in a param.
      #
      # **Symbols**, which is what the same call written in Ruby would pass.
      # With strings the markup form and the Ruby form were two different
      # things: `<field-list fields="title"/>` handed `"fields"`, the tag read
      # `attributes[:fields]`, found nothing and painted every column of the
      # table. It looked like it worked, which is the worst way for it not to.
      def pairs_of(attributes)
        attributes.to_s.scan(/([\w-]+)\s*=\s*(["'])(.*?)\2/).map do |name, _, value|
          written = value.start_with?("&") ? "(#{value[1..]})" : value.dump
          key = name.match?(/\A[a-z_][a-z0-9_]*\z/i) ? ":#{name}" : name.dump
          "#{key} => #{written}"
        end.join(", ")
      end

    end

  end

end
