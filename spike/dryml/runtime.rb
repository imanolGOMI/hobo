# The tag runtime of spike A, grown to whatever <table-plus> actually needs.
#
# Everything here exists because a real tag asked for it. Nothing is speculative.
# ActiveSupport is used for `try` and a couple of Hash helpers, which is fair:
# Hobo runs inside Rails anyway.

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

  # The output buffer, `this` and `scope` are *dynamic*, not per-tag state.
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
      def state = (Thread.current[:rapid_state] ||= { :buffer => nil, :this => nil, :scope => Scope.new })

      def buffer = state[:buffer]
      def this   = state[:this]
      def scope  = state[:scope]

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

  class Tag
    attr_reader :attributes, :all_attributes, :params

    def initialize(attributes = {}, params = {})
      @attributes = attributes
      @all_attributes = attributes.dup.freeze
      @params = params
      @old_stack = []
    end

    def this  = Context.this
    def scope = Context.scope

    def render
      Context.capture { content }
    end

    # --- extension points ----------------------------------------------------

    # A named extension point. The name may be computed at render time, which is
    # what `param="#{scope.field_name}-heading"` needs.
    def param(name, &default)
      override = @params[name]
      if override
        @old_stack.push(default)
        begin
          # `call`, not `instance_exec`: the block keeps the self of the tag that
          # wrote it, which is who owns the params it declares. Getting this
          # wrong makes overrides vanish without a word.
          override.call
        ensure
          @old_stack.pop
        end
      elsif default
        default.call
      end
      nil
    end

    # <old-x/> -- emit what the param would have rendered.
    def old
      default = @old_stack.last
      default&.call
      nil
    end

    # Whether the caller supplied a given param -- DRYML's all_parameters.
    def all_parameters = @params

    # --- markup --------------------------------------------------------------

    # `param_name` may be nil (no extension point) or :none (explicitly not one).
    def tag(name, attrs = {}, param_name = nil, &body)
      emit = proc do
        Context.buffer << "<#{name}#{format_attrs(attrs)}>"
        body&.call
        Context.buffer << "</#{name}>"
      end
      if param_name && param_name != :none
        param(param_name) { emit.call }
      else
        emit.call
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

      emit = proc { raw Rapid.render(name, attributes, :this => this, **params) }
      as ? param(as) { emit.call } : emit.call
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
      Rapid.attrs_for(:table) # placeholder: the real <table> renders its fields
      tag("td") { text this.to_s }
    end

    private

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

    # A param block written outside any tag -- a page template, or a test.
    # It becomes an anonymous tag that declares no params of its own.
    def markup(&block)
      outer = Tag.new({}, {})
      proc { outer.instance_exec(&block) }
    end

    # <extend tag="x"> -- prepend, so `super` is <old-x>.
    def extend_tag(name, &body)
      @tags.fetch(name).prepend(Module.new { define_method(:content, &body) })
    end

    def define_for(name, type, &body)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    def render(name, attributes = {}, this: Context.this, **params)
      klass = polymorphic_lookup(name, this) || @tags.fetch(name)
      Context.with(:this => this) { klass.new(attributes, params).render }
    end

    private

    def polymorphic_lookup(name, this)
      return nil unless @polymorphic.key?(name) && this
      this.class.ancestors.each do |ancestor|
        found = @polymorphic[name][ancestor]
        return found if found
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
