# A default English pluralisation, so an application does not need an `en`
# locale file just to say "Stories". It was alias_method_chain; a prepended
# module composes with anything else that wraps `human`.
module Hobo
  module EnPluralizationDefault
    def human(options = {})
      if I18n.locale.to_s.match(/^en/) && !(options[:count] == 1 || options[:count].blank?)
        options = options.merge(:default => ActiveSupport::Inflector.pluralize(@human))
      end
      super(options)
    end
  end
end

ActiveModel::Name.prepend(Hobo::EnPluralizationDefault)
