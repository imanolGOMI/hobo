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

  @tags = {}
  @attrs = {}
  @polymorphic = Hash.new { |h, k| h[k] = {} }
  @definitions = []

  class << self
    attr_reader :tags, :definitions

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
    def extend_tag(name, &body)
      record(name, :extend)
      @tags.fetch(name).prepend(Module.new { define_method(:content, &body) })
    end

    def define_for(name, type, &body)
      record(name, :define_for, type)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    # :this, :path and :from are taken; a param cannot be called any of those.
    def render(name, attributes = {}, this: Context.this, path: [], from: nil, **params)
      klass = polymorphic_lookup(name, dispatch_type(this), from) || @tags.fetch(name)
      Context.with(:this => this) { klass.new(attributes, params, :path => path).render }
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
