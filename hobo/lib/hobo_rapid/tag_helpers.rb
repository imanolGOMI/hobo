# One view helper per tag, so a template writes the name of the tag and that is
# all:
#
#   <%= search_filter :fields => "title, synopsis" %>
#   <%= filter_menu :field => "category" %>
#   <%= card book %>
#
# instead of naming the bridge every time:
#
#   <%= rapid_tag(:search_filter, nil, :fields => "title, synopsis") %>
#
# This is what the syntax gave you in DRYML: `<search-filter fields="..."/>` did
# not name a runtime, it named the tag. There is no new syntax here, so the name
# of the tag has to be what you write.
#
# They are rebuilt after deriving and on every reload, because a model's tags
# appear when it is derived and an application can define its own in a taglib.
#
# ## What is left alone
#
# A name ActionView already answers is left alone. `<%= form %>` would be fine,
# but if there were ever a tag called `link_to` or `render`, taking it would
# break a template somewhere else, and the failure would show up far from the
# cause. The tag is still reachable through `rapid_tag`, which collides with
# nothing.

module HoboRapid

  module TagHelpers

    # The helpers live inside this module and not in a loose one, so they can be
    # removed and put back on every reload without leaving behind a tag the
    # application has since deleted.
    def self.module
      @module ||= Module.new
    end

    def self.refresh!
      self.module.instance_methods(false).each { |name| self.module.send(:remove_method, name) }

      names.each do |name|
        next if reserved?(name)
        # The default is `INHERIT` and not nil, for the same reason `rapid_tag`
        # has one: `<%= filter_menu :field => "category" %>` inside a list is a
        # menu for **that** list, and passing nil left the tag with no record,
        # so it could not find the model and painted nothing at all.
        self.module.send(:define_method, name) do |this = HoboRapid::Helper::INHERIT, **attributes, &block|
          hobo_tag_helper(name, this, **attributes, &block)
        end
      end
    end

    # Every tag there is right now: the catalogue's, the ones derived per model,
    # and whatever the application defined.
    def self.names
      Rapid.definitions.map(&:name).uniq
    end

    RESERVED = %i[params request response controller flash session logger raw text].freeze

    def self.reserved?(name)
      return true if RESERVED.include?(name)
      ActionView::Base.method_defined?(name) || ActionView::Base.private_method_defined?(name)
    rescue NameError
      false
    end

  end


  # What a tag helper does. Kept apart from the generated ones so the logic is
  # written once and can be read.
  module TagHelperSupport

    def hobo_tag_helper(name, this = HoboRapid::Helper::INHERIT, **attributes, &block)
      # With a block, the block declares the params of **this** tag and not the
      # page's: `<%= index_page @books do %><% append_heading "…" %><% end %>`.
      # That is opening the element, which is what let you edit the whole page
      # in DRYML.
      return rapid_tag(name, this, **attributes) unless block

      rapid_tag(name, this, **attributes.merge(hobo_collect_params(&block)))
    end

    # Gathers what the block declares without letting it mix with what the view
    # has declared for its own page.
    def hobo_collect_params
      collected = {}
      outer = Thread.current[:hobo_taglib_frame]
      Thread.current[:hobo_taglib_frame] = { :tag => Struct.new(:params).new(collected), :old => -> {} }
      yield
      collected
    ensure
      Thread.current[:hobo_taglib_frame] = outer
    end

  end

end

if defined?(ActiveSupport)
  ActiveSupport.on_load(:action_view) do
    include HoboRapid::TagHelperSupport
    include HoboRapid::TagHelpers.module
  end
end
