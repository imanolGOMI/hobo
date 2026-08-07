# Spike A -- the four DRYML properties expressed as a small Ruby DSL.
#
# No template language, no parser: tags are Ruby objects, markup is built by
# method calls. The question this answers is whether Ruby's own facilities are
# enough for `param`, `<extend>`, polymorphic dispatch and the implicit `this`.
#
#   ruby spike/dryml/a_ruby_dsl.rb

require "cgi"
require "date"

module Rapid

  # --- the tag runtime -------------------------------------------------------

  class Tag
    attr_reader :attributes, :params, :this

    def initialize(attributes = {}, params = {}, this: nil)
      @attributes = attributes
      @params = params
      @this = this
      @out = +""
    end

    def self.attrs(*names)
      names.each { |n| define_method(n) { @attributes[n] } }
    end

    def render
      content
      @out
    end

    # A named extension point, declared right here in the markup. If the caller
    # supplied one, it runs *inside this tag*, and can call `old` to emit what
    # would have been there -- that is <old-x>.
    def param(name, &default)
      override = @params[name]
      if override
        (@old_stack ||= []).push(default)
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

    # <old-x/> -- emit the default of the param currently being overridden.
    def old
      default = (@old_stack ||= []).last
      instance_exec(&default) if default
      nil
    end

    def tag(name, attrs = {}, param_name = nil, &body)
      emit = proc do
        @out << "<#{name}#{format_attrs(attrs)}>"
        instance_exec(&body) if body
        @out << "</#{name}>"
      end
      param_name ? param(param_name) { emit.call } : emit.call
    end

    def text(string)
      @out << string.to_s
      nil
    end

    def raw(string)
      @out << string.to_s
      nil
    end

    # Renders another tag, so a tag can call a tag -- with its own params.
    def call_tag(name, attributes = {}, this: @this, **params, &block)
      raw Rapid.render(name, attributes, this: this, **params, &block)
    end

    private

    def format_attrs(attrs)
      attrs.map { |k, v| %( #{k.to_s.tr("_", "-")}="#{CGI.escapeHTML(v.to_s)}") }.join
    end
  end

  # --- the registry ----------------------------------------------------------

  @tags = {}
  @polymorphic = Hash.new { |h, k| h[k] = {} }

  class << self
    attr_reader :tags

    def define(name, superclass = Tag, &body)
      klass = Class.new(superclass) { define_method(:content, &body) }
      @tags[name] = klass
    end

    # <extend tag="page"> -- wraps the existing tag without knowing its class.
    # `super` inside the block is <old-page>.
    def extend_tag(name, &body)
      klass = @tags.fetch(name)
      klass.prepend(Module.new { define_method(:content, &body) })
    end

    # <def tag="view" for="Date"> -- dispatch on the type of `this`.
    def define_for(name, type, &body)
      @polymorphic[name][type] = Class.new(Tag) { define_method(:content, &body) }
    end

    def render(name, attributes = {}, this: nil, **params, &block)
      klass = polymorphic_lookup(name, this) || @tags.fetch(name)
      params = params.merge(:default => block) if block
      klass.new(attributes, params, :this => this).render
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


# --- 1. `param`: a page with nested named extension points --------------------

Rapid.define(:page) do
  tag("html") do
    tag("head", {}, :head) do
      tag("title", {}, :title) { text attributes[:title] }
    end
    tag("body", {}, :body) do
      tag("div", { :class => "navbar" }, :navbar) do
        tag("header", { :class => "container" }, :header) do
          param(:app_name) { tag("a", { :href => "/" }) { text "Hobo" } }
        end
      end
      tag("div", { :class => "container" }, :container) do
        param(:content)
      end
      tag("footer", {}, :page_footer)
    end
  end
end


# --- 2. `<extend>`: a theme changes the page without knowing its class --------

Rapid.extend_tag(:page) do
  # <old-page merge nav-location="sub"/>
  @attributes = { :nav_location => "sub" }.merge(@attributes)
  super()
end


# --- 3. polymorphic dispatch on the type of `this` ---------------------------

Rapid.define(:view) { text this.to_s }
Rapid.define_for(:view, Date)   { text this.strftime("%d/%m/%Y") }
Rapid.define_for(:view, String) { text CGI.escapeHTML(this) }


# --- what it looks like from the outside -------------------------------------

if __FILE__ == $PROGRAM_NAME
  require "date"

  puts "--- page with two params overridden ---"
  puts Rapid.render(:page,
                    { :title => "Home" },
                    :app_name => proc { raw "<b>My App</b>" },
                    :content => proc { text "Hello" })

  puts
  puts "--- a param that WRAPS the default instead of replacing it (<old-x>) ---"
  puts Rapid.render(:page,
                    { :title => "Home" },
                    :header => proc { tag("div", { :class => "wrap" }) { old } },
                    :content => proc { text "Hello" })

  puts
  puts "--- polymorphic view ---"
  puts Rapid.render(:view, {}, :this => Date.new(2026, 8, 7))
  puts Rapid.render(:view, {}, :this => "a <script> tag")
  puts Rapid.render(:view, {}, :this => 42)
end
