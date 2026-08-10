require 'hobo_fields/types/text'
module HoboFields
  module Types
    class TextileString < HoboFields::Types::Text

      include SanitizeHtml

      def to_html(xmldoctype = true)
        # Como el de :markdown, y por la misma razon: RedCloth no viene con
        # Hobo, asi que sin ella lo que salia era `LoadError: cannot load such
        # file -- redcloth` en mitad de una pagina derivada. Eso no le dice a
        # nadie que su modelo declara un campo `:textile`.
        begin
          require 'redcloth'
        rescue LoadError
          raise "a :textile field needs RedCloth: add `gem \"RedCloth\"` to the Gemfile"
        end

        if blank?
          ""
        else
          textilized = RedCloth.new(self, [ :hard_breaks ])
          textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
          HoboFields::SanitizeHtml.sanitize(textilized.to_html)
        end
      end

      HoboFields.register_type(:textile, self)
    end
  end
end
