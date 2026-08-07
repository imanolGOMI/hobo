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

  class Tag
    attr_reader :attributes, :all_attributes, :params, :this

    def initialize(attributes = {}, params = {}, this: nil, scope: Scope.new)
      @attributes = attributes
      @all_attributes = attributes.dup.freeze
      @params = params
      @this = this
      @scope = scope
      @old_stack = []
      @out = +""
    end

    def render
      content
      @out
    end

    # --- extension points ----------------------------------------------------

    # A named extension point. The name may be computed at render time, which is
    # what `param="#{scope.field_name}-heading"` needs.
    def param(name, &default)
      override = @params[name]
      if override
        @old_stack.push(default)
        begin
          instance_exec(&override)
        ensure
          @old_stack.pop
        end
      elsif default
        instance_exec(&default)
      end
      nil
    end

    # <old-x/> -- emit what the param would have rendered.
    def old
      default = @old_stack.last
      instance_exec(&default) if default
      nil
    end

    # Whether the caller supplied a given param -- DRYML's all_parameters.
    def all_parameters = @params

    # --- markup --------------------------------------------------------------

    # `param_name` may be nil (no extension point) or :none (explicitly not one).
    def tag(name, attrs = {}, param_name = nil, &body)
      emit = proc do
        @out << "<#{name}#{format_attrs(attrs)}>"
        instance_exec(&body) if body
        @out << "</#{name}>"
      end
      if param_name && param_name != :none
        param(param_name) { emit.call }
      else
        emit.call
      end
    end

    def text(string) = (@out << CGI.escapeHTML(string.to_s); nil)
    def raw(string)  = (@out << string.to_s; nil)

    # --- calling other tags --------------------------------------------------

    # `as:` makes the call site itself an extension point -- DRYML's bare
    # `<search-filter param/>`. `merge_params:` forwards the caller's leftover
    # params down, which is `merge-params`.
    def call_tag(name, attributes = {}, as: nil, merge_params: false, this: @this, **params, &block)
      params = params.merge(:default => block) if block
      params = @params.merge(params) if merge_params

      emit = proc do
        raw Rapid.render(name, attributes, :this => this, :scope => @scope, **params)
      end
      as ? param(as) { emit.call } : emit.call
    end

    # --- context -------------------------------------------------------------

    def with_scope(vars)
      previous = @scope
      @scope = @scope.merge(vars)
      yield
    ensure
      @scope = previous
    end

    def scope = @scope

    def with_this(record)
      previous = @this
      @this = record
      yield
    ensure
      @this = previous
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

    # <extend tag="x"> -- prepend, so `super` is <old-x>.
    def extend_tag(name, &body)
      @tags.fetch(name).prepend(Module.new { define_method(:content, &body) })
    end

    def define_for(name, type, &body)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    def render(name, attributes = {}, this: nil, scope: Scope.new, **params)
      klass = polymorphic_lookup(name, this) || @tags.fetch(name)
      klass.new(attributes, params, :this => this, :scope => scope).render
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
