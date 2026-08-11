# `hobo.` -- everything Hobo puts in a template, in one place.
#
#   <%= hobo.field_list :fields => "title, year" %>
#   <%= hobo.card %>
#   <% hobo.append_heading " — La Biblioteca" %>
#
# In ERB, in Slim, in HAML: it is a Ruby call, so it works wherever Ruby does.
# In a `.dryml` you write `<field-list/>`, and this does not come into it.
#
# ## Why not a helper per tag
#
# There was one -- `<%= field_list %>`, `<%= card %>` -- and it was dropped
# (2026-08-11, with Imanol). Sixty-three names, and read in a template not one
# of them says where it comes from: `<%= form %>`, `<%= section %>`, `<%= view
# %>`, `<%= page %>` look exactly like a helper of the application's or of
# Rails'.
#
# Only one of the sixty-three collided with Rails today. The problem is not
# today: the day an application defines a helper called `card` or `section`, it
# wins and the tag disappears -- with nothing raised and nothing to grep for.
# Behind `hobo.` that cannot happen, and `hobo.param` exists, which as a bare
# name it could not.
#
# ## Why an object and not a module
#
# `Hobo.field_list(…)` would be a module method, and a module cannot see the
# view: the tags need the forgery token, the acting user and `capture` for
# blocks, and all three live there. `hobo` is a helper that answers with an
# object bound to **this** view, so it has them.

module HoboRapid

  # What `hobo` answers with: the tags, bound to one view.
  class ViewTags

    # The verbs that retouch the derived page (hobo_rapid/params.rb). They are
    # on the view because that is where they keep what they declare, and they
    # are named here so `hobo.append_heading` reaches them.
    VERBS = %i[param replace without param_content sortable_headings].freeze

    def initialize(view)
      @view = view
    end

    # Every tag there is, asked at call time rather than defined up front: a
    # taglib can define one at any point, and a list built at boot would not
    # have it.
    def method_missing(name, *args, **attributes, &block)
      return @view.send(name, *args, **attributes, &block) if verb?(name)
      return @view.hobo_tag_helper(name, *args, **attributes, &block) if tag?(name)

      raise NoMethodError, <<~ERROR
        Hobo no tiene ningun tag ni verbo llamado `#{name}`.

        Los tags que hay: bin/rails hobo:tags
      ERROR
    end

    def respond_to_missing?(name, include_private = false)
      verb?(name) || tag?(name) || super
    end

    private

    def verb?(name) = VERBS.include?(name) || name.to_s.match?(HoboRapid::Params::PSEUDO)

    def tag?(name) = defined?(Rapid) && Rapid.definitions.any? { |definition| definition.name == name.to_sym }

  end


  module TagHelpers

    # The one name Hobo adds to a template.
    def hobo = @hobo_tags ||= HoboRapid::ViewTags.new(self)

    def hobo_tag_helper(name, this = HoboRapid::Helper::INHERIT, **attributes, &block)
      # With a block, the block declares the params of **this** tag and not the
      # page's: `<%= hobo.index_page @books do %>…<% end %>`. That is opening
      # the element, which is what let you edit the whole page in DRYML.
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
  ActiveSupport.on_load(:action_view) { include HoboRapid::TagHelpers }
end
