# `config.hobo.show_translation_keys`: every translated string comes out with
# its key in front, so a translator can see which key produced what.
module Hobo
  module ShowTranslationKeys
    def translate(key = nil, throw: false, raise: false, locale: nil, **options)
      translation = super
      return translation unless translation.is_a?(String)
      keys = I18n.normalize_keys(locale || I18n.locale, key, options[:scope]).join(".")
      "[#{keys}]#{translation}"
    end
    alias_method :t, :translate
  end
end

I18n.singleton_class.prepend(Hobo::ShowTranslationKeys)
