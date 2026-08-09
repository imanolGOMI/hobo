# The words the catalogue puts on a page.
#
# Every string a derived page shows comes through here, and it comes with its
# English text written at the point of use:
#
#     t(:"actions.create", "Create")
#     t(:"index.new_link", "New %{name}", :name => singular.downcase)
#
# **The default is the translation.** There is no `hobo.en.yml` saying the same
# words a second time, because two lists of the same strings drift apart and the
# one nobody reads is the one that is wrong. A language is added by writing one
# file -- `config/locales/hobo.es.yml` is the one that ships -- and an
# application that wants different English writes `hobo.en.yml` of its own,
# which is the ordinary Rails way of overriding a gem's translations.
#
# The interpolation matters more than it looks: "Nuevo %{name}" and "New
# %{name}" put the noun in different places and agree with it differently, which
# is exactly what a translator cannot do with "Nuevo " + noun.

module HoboRapid

  module Translation

    # `t` inside a tag. The key is relative to `hobo.`, so the tags never write
    # the namespace and an application always sees it.
    def t(key, default, **interpolations) = HoboRapid.translate(key, default, **interpolations)

  end

  # I18n travels with ActiveSupport, so it is here in any application. It is not
  # necessarily here in a suite that loads the runtime and nothing else, and the
  # catalogue has to be renderable on its own -- that is what the piece tests do.
  def self.translate(key, default, **interpolations)
    return interpolate(default, interpolations) unless defined?(::I18n)
    ::I18n.t("hobo.#{key}", :default => default, **interpolations)
  end

  # The answer with no I18n: the English written at the point of use, with its
  # values in place.
  def self.interpolate(default, interpolations)
    interpolations.empty? ? default : default % interpolations
  end

end

require "rapid"

Rapid::Tag.include(HoboRapid::Translation)
