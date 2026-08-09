require 'hobo_fields/types/text'

module HoboFields
  module Types

    # Markdown, unsanitised. `body :markdown` in a model, and the value knows
    # how to paint itself -- which is what makes `<view:body/>` able to decide
    # from the type alone.
    #
    # The engine is looked up **when it is used**, not when this file loads.
    # It used to be decided at load time with `defined?(RDiscount)`, and a gem
    # that Bundler had not required yet was simply not there: the answer was
    # `nil`, and `to_html` died with "undefined method 'new' for nil". The
    # workaround was to stop requiring these two files at all -- with a note
    # saying they would be "loaded later", which never happened -- so `:markdown`
    # was not a type any more. It came back as `uninitialized constant
    # HoboFields::Types::MarkdownString` the first time a real application
    # declared a markdown field.
    module MarkdownEngine

      ENGINES = [["RDiscount", "RDiscount"], ["Kramdown", "Kramdown::Document"],
                 ["Maruku", "Maruku"], ["Markdown", "Markdown"]].freeze

      def self.find
        name = ENGINES.find { |top, _| Object.const_defined?(top) }
        name && name.last.constantize
      end

      def self.render(text)
        engine = find
        unless engine
          raise "a :markdown field needs a gem that turns markdown into html: " \
                "add `gem \"kramdown\"` (or rdiscount) to the Gemfile"
        end
        engine.new(text).to_html
      end

    end

    class RawMarkdownString < HoboFields::Types::Text

      HoboFields.register_type(:raw_markdown, self)

      def to_html(xmldoctype = true)
        blank? ? "" : MarkdownEngine.render(self).html_safe
      end

    end

  end
end
