# Rapid: the tag runtime.
#
# This is the DRYML remix of layer 3 in PLAN.md -- DRYML's *semantics* on a Ruby
# substrate, with no template language and no parser. Tags are Ruby objects and
# markup is built by method calls.
#
# What it keeps from DRYML, because these are the reasons Hobo exists:
#
#   param       extension points declared in the markup, with no API agreed in
#               advance. It is the whole mechanism of the theme contract
#   <extend>    extending a tag from another gem without knowing its class
#   for="Date"  dispatch on the type of the value being rendered
#   this        the implicit context
#
# The old DRYML compiler is still in this gem, under lib/dryml. It is not dead
# code: its parser is the front end of the updater that will migrate the
# templates of existing applications. See PLAN.md, decision 6.
#
# The four dynamic pieces -- buffer, `this`, `scope` and the stack behind `old`
# -- live in Rapid::Context, and the reason is in spike/dryml/README.md: a param
# block is written inside one tag and run while another is rendering.

require "cgi"
require "hobo_support"
require "active_support/core_ext/object/try"
require "active_support/core_ext/object/blank"

require_relative "rapid/scope"
require_relative "rapid/context"
require_relative "rapid/parameter"
require_relative "rapid/tag"

module Rapid

  # There is no Boolean class in Ruby, and a view has to be able to dispatch on
  # one. Hobo has always had this.
  class Boolean; end

  # One definition of one tag, and where it came from.
  #
  # The registry is global -- a tag is looked up by name and an application has
  # one catalogue -- so the *last* definition of a name wins, quietly. That is
  # what makes plugins possible (piece 17: a plugin defines tags and defining
  # them is installing them) and it is also how a stand-in from a spike ended up
  # painting the pages of the real application when the gems were merged.
  #
  # So every definition says who made it. Nothing in the runtime reads this; it
  # is for `rails hobo:tags`, which is the only way to see from outside that a
  # name has two owners.
  Definition = Struct.new(:name, :kind, :type, :source, :keyword_init => true)

  # **What a class name means, and who decides how it looks.**
  #
  # The catalogue writes the *role* of an element -- `index-page`,
  # `record-actions`, `field`, `count` -- and a theme says what those look like.
  # Until now the catalogue wrote Bootstrap's own class names (`card card-body
  # bg-body-tertiary p-3 mb-4`), which meant there was one possible theme: an
  # application without Bootstrap got its markup anyway, full of names that
  # meant nothing, and a second theme would have had to fight them.
  #
  # A theme fills this table; the runtime only carries it. With it empty --
  # `--theme=none` -- what comes out is the semantic names and nothing else,
  # which is exactly what somebody bringing their own design wants.
  @class_map = {}

  @tags = {}
  @attrs = {}
  @polymorphic = Hash.new { |h, k| h[k] = {} }
  @definitions = []

  # Last resort for a name nobody defined.
  #
  # Empty here **on purpose**: for code written today a tag that does not exist
  # is a typo, and the loud KeyError is the right answer. It is `hobo_dryml` that
  # puts one in, because Hobo 2 *generated* tags into each application --
  # `<signup-page>`, and a `<facturar-page>` for every lifecycle transition --
  # and those generated files are the ones an update throws away.
  @derivers = []

  # Los params que alguien paso y nadie recogio, por tag. Ver
  # `Rapid.unclaimed_params`.
  @unclaimed = {}

  class << self
    attr_reader :tags, :definitions

    # Where the table comes from. The runtime keeps the *mechanism*; who decides
    # is Hobo's business -- and it can be a different answer per request, because
    # a subsite may wear another theme.
    attr_accessor :class_map_source

    def class_map = (@class_map_source ? @class_map_source.call : @class_map) || {}

    # `dress("index-page stories")` -> whatever the theme adds to each of those.
    def dress(names)
      map = class_map
      tokens = names.to_s.split
      return names if map.empty? || tokens.empty?

      tokens.flat_map { |token| [token, *map[token].to_s.split] }.uniq.join(" ")
    end

    # A theme's whole vocabulary, in one call. Themes go through
    # HoboRapid::Theme; this is the runtime's own door, for a test.
    def dress_with(map)
      @class_map = @class_map.merge(map.transform_keys(&:to_s))
    end

    def define(name, attrs: [], superclass: Tag, &body)
      record(name, :define)
      @attrs[name] = attrs
      @tags[name] = Class.new(superclass) { define_method(:content, &body) }
    end

    def attrs_for(name) = @attrs.fetch(name, [])

    # A parameter tag: `<x: attr="v" replace><nested:>...</nested:></x>`.
    def parameter(attributes: {}, params: {}, replace: false, &content)
      Parameter.new(:attributes => attributes, :params => params, :replace => replace, &content)
    end

    # The common case: a parameter that is only content.
    def markup(&block) = Parameter.new(&block)

    # <extend tag="x"> -- prepend, so `super` is <old-x>.
    #
    # With no `for:` it reaches **every** definition of that name: the plain one
    # and each per-type one. That is what "all the index pages" has to mean --
    # a derived page is defined per model, so extending only the plain tag would
    # extend the one nobody renders. With `for:` it is that model's alone.
    # `with:` is for a caller that brings the module already made -- an ERB
    # taglib, whose `content` has to call `super()` from inside a block.
    def extend_tag(name, type = nil, with: nil, &body)
      record(name, :extend, type)
      extension = with || Module.new { define_method(:content, &body) }

      if type
        @polymorphic[name].fetch(type).prepend(extension)
      else
        # `<extend tag="signup-page">` before anybody has rendered one: the
        # deriver has to run here too, or the extension has nothing to attach to
        # and one line takes the whole taglib down with it.
        @derivers.each { |deriver| deriver.call(name) } if @tags[name].nil? && @polymorphic[name].empty?
        @tags[name]&.prepend(extension)
        @polymorphic[name].each_value { |klass| klass.prepend(extension) }
        raise KeyError, "tag #{name.inspect} is not defined" if @tags[name].nil? && @polymorphic[name].empty?
      end
    end

    def define_for(name, type, &body)
      record(name, :define_for, type)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    # :this, :path and :from are taken; a param cannot be called any of those.
    def render(name, attributes = {}, this: Context.this, path: [], from: nil, **params)
      klass = polymorphic_lookup(name, dispatch_type(this), from) || @tags[name] || derive(name)
      Context.with(:this => this) { klass.new(attributes, params, :path => path, :name => name).render }
    end

    # `Rapid.derives { |name| ... }` -- a chance to define a tag the first time
    # somebody asks for it. The block returns truthy if it defined one.
    def derives(&block) = @derivers << block

    # Params the caller handed to a tag that never asked for them: a name that
    # was renamed between versions, or a typo. What Rapid does with it is decide
    # nothing -- it keeps the list, and whoever is hosting says it out loud.
    # `Hobo` prints them in development; a test reads them.
    def unclaimed_params(tag_name, names)
      names.each { |name| (@unclaimed[tag_name] ||= []) << name unless @unclaimed[tag_name]&.include?(name) }
    end

    def unclaimed = @unclaimed

    def forget_unclaimed = @unclaimed = {}

    def derive(name)
      @derivers.each do |deriver|
        return @tags.fetch(name) if deriver.call(name) && @tags.key?(name)
      end
      raise KeyError, "no hay ningun tag llamado #{name.inspect}"
    end

    # What a polymorphic tag dispatches on.
    #
    # Not `this.class`: a rich type is a real class, so a `:markdown` field does
    # hold a Markdown -- but a **blank** field holds nil, and it still has to
    # render as the kind of thing it is. The parent model knows what the field
    # was declared as, and that is the answer. And there is no Boolean class in
    # Ruby, so `true` and `false` get one.
    def dispatch_type(this)
      return Boolean if this == true || this == false
      # A collection dispatches on what it holds, not on being a collection:
      # an index page of stories is a page of *stories*. Hobo has always asked
      # the relation for its member_class.
      return this.member_class if this.respond_to?(:member_class) && this.member_class
      return this.class if this

      parent, field = Context.this_parent, Context.this_field
      return nil unless parent && field && parent.class.respond_to?(:attr_type)
      parent.class.attr_type(field)
    end

    # Whether a polymorphic definition exists for what `this` is. A caller
    # outside the runtime needs this to know whether a derived tag exists before
    # deciding to use it.
    def polymorphic?(name, this) = !polymorphic_lookup(name, dispatch_type(this), nil).nil?

    # The definitions of one tag, oldest first. The last one is the one in
    # force; anything before it has been shadowed.
    def definitions_for(name) = @definitions.select { |d| d.name == name }

    private

    # The file that called `define`, `define_for` or `extend_tag` -- two frames
    # up, because this is called from them.
    def record(name, kind, type = nil)
      @definitions << Definition.new(:name => name, :kind => kind, :type => type,
                                     :source => caller_locations(2, 1)&.first&.path)
    end

    def polymorphic_lookup(name, type, from)
      return nil unless @polymorphic.key?(name) && type.is_a?(Module)
      type.ancestors.each do |ancestor|
        found = @polymorphic[name][ancestor]
        return found if found && !found.equal?(from)
      end
      nil
    end
  end

end
