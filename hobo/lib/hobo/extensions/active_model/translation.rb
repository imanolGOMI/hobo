# The same default for attribute names, as a prepended module rather than an
# alias chain.
module Hobo
  module EnAttributePluralizationDefault
    def human_attribute_name(attribute, options = {})
      if I18n.locale.to_s.match(/^en/) && !options[:count].blank?
        default = options[:count] == 1 ?
                    attribute.to_s.singularize.humanize :
                    attribute.to_s.pluralize.humanize
        options = options.merge(:default => default)
      end
      super(attribute, options)
    end
  end
end

ActiveModel::Translation.prepend(Hobo::EnAttributePluralizationDefault)

ActiveModel::Translation.class_eval do

    # adds a default pluralization and singularization for english
    # useful to avoid to set a locale 'en' file and avoid
    # to pass around pluralize calls for 'en' defaults in hobo

    # Similar to human_name_attributes, this method retrieves the localized help string
    # of an attribute if it is defined as the key "activemodel.attribute_help.<attribute_name>",
    # otherwise it returns "".
    def attribute_help(attribute, options = {})
      defaults = lookup_ancestors.map do |klass|
        :"#{self.i18n_scope}.attribute_help.#{klass.to_s.underscore}.#{attribute}"
      end

      defaults << :"attribute_help.#{attribute}"
      defaults << options.delete(:default) if options[:default]
      defaults << ''

      options.reverse_merge! :count => 1, :default => defaults
      I18n.translate(defaults.shift, options)
    end

end
