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

    class << self

      def transform(source)
        return source unless source.include?(":")

        source.gsub(CLOSE) { "<% end %>" }
              .gsub(OPEN) { opening(Regexp.last_match) }
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

      # `class="big" id="x"` -> `"class" => "big", "id" => "x"`, and `&expr` is
      # Ruby, the same as everywhere else in a param.
      def pairs_of(attributes)
        attributes.to_s.scan(/([\w-]+)\s*=\s*(["'])(.*?)\2/).map do |name, _, value|
          written = value.start_with?("&") ? "(#{value[1..]})" : value.dump
          %("#{name}" => #{written})
        end.join(", ")
      end

    end

  end

end
