require 'hobo_fields/types/raw_markdown_string'

module HoboFields
  module Types

    # The same, sanitised: this is what `:markdown` means, and it is the one an
    # application should use for anything a person typed.
    class MarkdownString < RawMarkdownString

      include SanitizeHtml

      HoboFields.register_type(:markdown, self)

      def to_html(xmldoctype = true)
        blank? ? "" : HoboFields::SanitizeHtml.sanitize(MarkdownEngine.render(self))
      end

    end

  end
end
