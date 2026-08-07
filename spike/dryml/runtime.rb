# The tag runtime of spike A, grown to whatever the real tags actually need.
#
# Everything here exists because a real tag, or a real DRYML feature, asked for
# it. Nothing is speculative. ActiveSupport is used for `try` and a couple of
# Hash helpers, which is fair: Hobo runs inside Rails anyway.

require "cgi"
require "active_support/core_ext/object/try"
require "active_support/core_ext/object/blank"

module Rapid

  AJAX_ATTRS = [:update, :updates, :ajax, :success, :failure, :complete, :before].freeze

  # A scope is a stack of variables that inner tags can read -- DRYML's
  # <set-scoped>. Read as `scope.field_name`.
  class Scope
    def initialize(vars = {}) = @vars = vars
    def merge(more) = Scope.new(@vars.merge(more))
    def [](name) = @vars[name]
    def respond_to_missing?(name, priv = false) = @vars.key?(name) || super
    def method_missing(name, *args)
      @vars.key?(name) ? @vars[name] : super
    end
  end

  # The output buffer, `this`, `scope` and the stack of defaults behind `old`
  # are *dynamic*, not per-tag state.
  #
  # This is the whole lesson of spike C. A param block is written inside one tag
  # but executed while another is rendering, and Ruby closures capture `self`
  # lexically -- so the block must keep the self of the tag that wrote it (that
  # is who owns its params) while writing into the buffer, `this` and `scope` of
  # whoever is rendering right now.
  #
  # DRYML's part_context.rb and scoped_variables exist for exactly this.
  module Context
    class << self
      def state
        Thread.current[:rapid_state] ||=
          { :buffer => nil, :this => nil, :scope => Scope.new, :old_stack => [] }
      end

      def buffer    = state[:buffer]
      def this      = state[:this]
      def scope     = state[:scope]
      def old_stack = state[:old_stack]

      def with(**changes)
        previous = state.dup
        state.merge!(changes)
        yield
      ensure
        Thread.current[:rapid_state] = previous
      end

      def capture
        with(:buffer => +"") do
          yield
          buffer
        end
      end
    end
  end

  # What a caller supplies for a param: DRYML's parameter tag, `<x: attr="v">`.
  #
  # A parameter is not just a block of content. It may also carry attributes for
  # the element or tag call it customises, parameters *for that tag call* --
  # which is what makes nesting work -- and the `replace` flag, which takes the
  # element away instead of filling it in.
  #
  #   <heading:>Title</heading:>            Rapid.parameter { text "Title" }
  #   <heading: class="big">Title</heading: Rapid.parameter(:attributes => { :class => "big" }) { ... }
  #   <heading: replace><h2/></heading:>    Rapid.parameter(:replace => true) { ... }
  #   <table:><row:>...</row:></table:>     Rapid.parameter(:params => { :row => ... })
  class Parameter
    attr_reader :attributes, :params, :content

    def initialize(attributes: {}, params: {}, replace: false, &content)
      @attributes = attributes
      @params = params
      @replace = replace
      @content = self.class.normalize(content)
    end

    def replace? = @replace
    def content? = !@content.nil?

    # Parameters for the tag being called only mean something at a tag call.
    def nested? = !@params.empty?

    # A bare block is the common case: content, and nothing else.
    def self.wrap(value) = value.is_a?(Parameter) ? value : new(&value)

    # A block written inside a tag already carries the right `self` and has to
    # keep it -- that is who owns the params it declares. A block written
    # outside any tag (a page template, or a test) has no tag to be, so it gets
    # an anonymous one.
    def self.normalize(block)
      return nil if block.nil?
      return block if block.binding.receiver.is_a?(Tag)
      outer = Tag.new
      proc { outer.instance_exec(&block) }
    end
  end

  class Tag
    attr_reader :attributes, :all_attributes, :params

    # `path` is how the outside world addresses the params this tag declares: a
    # list of param names to nest through, or nil when nothing leads here
    # because the call site was not itself a param.
    attr_reader :param_path

    def initialize(attributes = {}, params = {}, path: nil)
      @attributes = attributes
      @all_attributes = attributes.dup.freeze
      @params = params
      @param_path = path
    end

    def this  = Context.this
    def scope = Context.scope

    def render
      Context.capture { content }
    end

    # --- extension points ----------------------------------------------------

    # A named extension point with no element of its own -- DRYML's
    # `<do param="x">default</do>`. The name may be computed at render time,
    # which is what `param="#{scope.field_name}-heading"` needs.
    def param(name, &default)
      parameter = parameter_for(name, :bare)
      parameter ? render_content(parameter, default) : default&.call
      nil
    end

    # <old-x/> -- emit what the param would have rendered. The default is popped
    # while it runs, so an <old-x> inside a default does not call itself.
    def old
      stack = Context.old_stack
      return nil if stack.empty?
      Context.with(:old_stack => stack[0..-2]) { stack.last&.call }
      nil
    end

    # Whether the caller supplied a given param -- DRYML's all_parameters.
    def all_parameters = @params

    # --- markup --------------------------------------------------------------

    # An element that is itself an extension point -- `<h3 param="heading">`.
    # `param_name` may be nil (no extension point) or :none (explicitly not one).
    #
    # Filling it in keeps the element and replaces its content, merging the
    # parameter's attributes; `replace` takes the element away as well, and then
    # `old` emits the whole original element -- DRYML's `<x: restore/>`.
    def tag(name, attrs = {}, param_name = nil, &body)
      parameter = param_name && param_name != :none ? parameter_for(param_name, :element) : nil
      whole_element = proc { emit_element(name, attrs, &body) }

      if parameter.nil?
        whole_element.call
      elsif parameter.replace?
        render_content(parameter, whole_element)
      else
        emit_element(name, merge_attributes(attrs, parameter.attributes)) do
          render_content(parameter, body)
        end
      end
      nil
    end

    def text(string) = (Context.buffer << CGI.escapeHTML(string.to_s); nil)
    def raw(string)  = (Context.buffer << string.to_s; nil)

    # --- calling other tags --------------------------------------------------

    # `as:` makes the call site itself an extension point -- DRYML's bare
    # `<search-filter param/>`. `merge_params:` forwards the caller's leftover
    # params down, which is `merge-params`.
    def call_tag(name, attributes = {}, as: nil, merge_params: false, this: Context.this, **params, &block)
      params = params.merge(:default => block) if block
      params = @params.merge(params) if merge_params

      exposed_as = as && as != :none ? as : nil
      parameter = exposed_as ? parameter_for(exposed_as, :call) : nil
      path = exposed_as && @param_path ? @param_path + [exposed_as] : nil

      if parameter && !parameter.replace?
        attributes = merge_attributes(attributes, parameter.attributes)
        # The caller's nested params win over the ones this tag fills in. That
        # is the whole point of exposing the call as a param: without it the
        # params of the tag being called would be unreachable from outside.
        params = params.merge(parameter.params)
        params = params.merge(:default => shadowing_default(parameter, params[:default])) if parameter.content?
      end

      # `from:` is what makes `<form>` inside `<def tag="form" for="Story">`
      # reach the base definition instead of calling itself: a polymorphic tag
      # never dispatches back to the class doing the calling. It is DRYML's
      # `super`, decided by who wrote the call and not by what is on the stack.
      whole_call = proc do
        raw Rapid.render(name, attributes,
                         :this => this, :path => path, :from => self.class, **params)
      end
      parameter&.replace? ? render_content(parameter, whole_call) : whole_call.call
      nil
    end

    # --- context -------------------------------------------------------------

    def with_scope(vars, &block)
      Context.with(:scope => Context.scope.merge(vars), &block)
    end

    def with_this(record, &block)
      Context.with(:this => record, &block)
    end

    # --- odds and ends the templates use -------------------------------------

    # The declared attribute names of another tag, so a tag can split its own
    # attributes between the tags it forwards them to.
    def attrs_for(tag_name) = Rapid.attrs_for(tag_name)

    def comma_split(value)
      case value
      when nil then []
      when String then value.strip.split(/\s*,\s*/)
      else Array(value).map(&:to_s)
      end
    end

    # Stands in for the controller instance variables the original reads.
    def controller_ivar(_name) = nil

    def default_row
      tag("td") { text this.to_s }
    end

    private

    # The three kinds of param site: a bare `param`, an element carrying one,
    # and a tag call exposed with `as:`. Only the last can take nested params,
    # because only it has another tag's params to pass them to.
    SITES = { :bare => "no tiene elemento", :element => "es un elemento" }.freeze

    def parameter_for(name, kind)
      value = @params[name]
      return nil unless value

      parameter = Parameter.wrap(value)
      if parameter.nested? && kind != :call
        raise ArgumentError, "el param #{name.inspect} #{SITES[kind]}, no es una llamada a " \
                             "otro tag, asi que no admite params anidados"
      end
      parameter
    end

    # The parameter's content replaces the default, and the default is what
    # `old` reaches. A parameter with no content of its own -- one that only
    # carries attributes or nested params -- leaves the default alone.
    def render_content(parameter, default)
      if parameter.content?
        Context.with(:old_stack => Context.old_stack + [default]) { parameter.content.call }
      else
        default&.call
      end
      nil
    end

    # Content given to a tag-call param becomes that call's default content. If
    # the tag was already supplying some, that is what `old` reaches.
    def shadowing_default(parameter, shadowed)
      return parameter.content unless shadowed
      # `merge_params` can hand a tag its own parameter back. Shadowing it with
      # itself would make `old` call the override again, for ever.
      shadowed = Parameter.wrap(shadowed)
      return parameter.content if shadowed.content.equal?(parameter.content)
      Parameter.new { render_content(parameter, shadowed.content) }
    end

    # DRYML merges the class attribute rather than overwriting it, which is how
    # `<card: class="odd">` on `<div class="card">` ends up as "card odd".
    def merge_attributes(base, extra)
      return base if extra.nil? || extra.empty?
      merged = base.merge(extra)
      merged[:class] = "#{base[:class]} #{extra[:class]}" if base[:class] && extra[:class]
      merged
    end

    VOID_ELEMENTS = %w[area base br col embed hr img input link meta source track wbr].freeze

    def emit_element(name, attrs)
      if VOID_ELEMENTS.include?(name.to_s)
        body = block_given? ? Context.capture { yield } : ""
        raise ArgumentError, "<#{name}> es un elemento vacio y no puede llevar contenido; " \
                             "para poner algo en su sitio hace falta `replace`" unless body.empty?
        Context.buffer << "<#{name}#{format_attrs(attrs)}>"
        return nil
      end

      Context.buffer << "<#{name}#{format_attrs(attrs)}>"
      yield if block_given?
      Context.buffer << "</#{name}>"
      nil
    end

    def format_attrs(attrs)
      attrs.reject { |_, v| v.nil? || v == false }
           .map { |k, v| %( #{k.to_s.tr("_", "-")}="#{CGI.escapeHTML(v.to_s)}") }.join
    end
  end

  # --- registry --------------------------------------------------------------

  @tags = {}
  @attrs = {}
  @polymorphic = Hash.new { |h, k| h[k] = {} }

  class << self
    attr_reader :tags

    def define(name, attrs: [], superclass: Tag, &body)
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
      @tags.fetch(name).prepend(Module.new { define_method(:content, &body) })
    end

    def define_for(name, type, &body)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    # :this, :path and :from are taken; a param cannot be called any of those.
    def render(name, attributes = {}, this: Context.this, path: [], from: nil, **params)
      klass = polymorphic_lookup(name, this, from) || @tags.fetch(name)
      Context.with(:this => this) { klass.new(attributes, params, :path => path).render }
    end

    private

    def polymorphic_lookup(name, this, from)
      return nil unless @polymorphic.key?(name) && this
      this.class.ancestors.each do |ancestor|
        found = @polymorphic[name][ancestor]
        return found if found && !found.equal?(from)
      end
      nil
    end
  end

end

# partition_hash, from hobo_support -- there is still no core equivalent.
class Hash
  def partition_hash(keys)
    yes, no = {}, {}
    each { |k, v| (keys.include?(k) ? yes : no)[k] = v }
    [yes, no]
  end
end
