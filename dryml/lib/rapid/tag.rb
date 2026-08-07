module Rapid

  class Tag
    attr_reader :attributes, :all_attributes, :params

    # `path` is how the outside world addresses the params this tag declares: a
    # list of param names to nest through, or nil when nothing leads here
    # because the call site was not itself a param.
    attr_reader :param_path

    def initialize(attributes = {}, params = {}, path: nil)
      # `without-x` is an attribute that takes an extension point away, so it is
      # consumed here and never reaches the markup -- as DRYML does.
      without, attributes = attributes.partition { |name, _| name.to_s.start_with?("without_") }
                                      .map(&:to_h)
      @without = without
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
      return nil if without?(name)
      around(name) { render_content(name, parameter_for(name, :bare), &default) }
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
    def tag(element, attrs = {}, param_name = nil, &body)
      param_name = nil if param_name == :none

      if param_name.nil?
        emit_element(element, attrs, &body)
        return nil
      end
      return nil if without?(param_name)

      parameter = parameter_for(param_name, :element)

      around(param_name) do
        if parameter&.replace?
          # `<x: replace/>` with no content takes the element away and puts
          # nothing in its place.
          original = parameter.content? ? proc { emit_element(element, attrs, &body) } : nil
          render_content(param_name, parameter, &original)
        else
          merged = parameter ? merge_attributes(attrs, parameter.attributes) : attrs
          emit_element(element, merged) { render_content(param_name, parameter, &body) }
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
      return nil if exposed_as && without?(exposed_as)

      parameter = exposed_as ? parameter_for(exposed_as, :call) : nil
      path = exposed_as && @param_path ? @param_path + [exposed_as] : nil
      reached = nil

      if parameter && !parameter.replace?
        attributes = merge_attributes(attributes, parameter.attributes)
        # The caller's nested params win over the ones this tag fills in. That
        # is the whole point of exposing the call as a param: without it the
        # params of the tag being called would be unreachable from outside.
        params = params.merge(parameter.params)
      end

      # Content given to a tag-call param, and any prepend/append around it, act
      # on the *content the call is handed* -- its :default param. That is how
      # `<append-decorated-help:>` ends up inside the <a> and not after it.
      # Whatever the caller hung around this call is consumed *here*. Without
      # this, `merge_params` would forward it to the tag being called and a
      # param of the same name one level down would apply it a second time.
      params = params.except(*PSEUDO.map { |prefix| :"#{prefix}_#{exposed_as}" }) if exposed_as

      if exposed_as && !parameter&.replace? && (parameter&.content? || inner_pseudo?(exposed_as))
        reached = [false] if inner_pseudo?(exposed_as)
        supplied = call_default(parameter, params[:default])
        params = params.merge(:default => Parameter.new do
          reached[0] = true if reached
          render_content(exposed_as, parameter, &supplied)
        end)
      end

      # `from:` is what makes `<form>` inside `<def tag="form" for="Story">`
      # reach the base definition instead of calling itself: a polymorphic tag
      # never dispatches back to the class doing the calling. It is DRYML's
      # `super`, decided by who wrote the call and not by what is on the stack.
      whole_call = proc do
        raw Rapid.render(name, attributes,
                         :this => this, :path => path, :from => self.class, **params)
      end

      around(exposed_as) do
        if parameter&.replace?
          original = parameter.content? ? whole_call : nil
          render_content(exposed_as, parameter, &original)
        else
          whole_call.call
        end
      end

      if reached && !reached[0]
        raise ArgumentError, "prepend-#{exposed_as} / append-#{exposed_as} no llegaron a ninguna " \
                             "parte: <#{name}> no pinta el contenido que se le pasa"
      end
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

    # --- the pseudo-parameters ------------------------------------------------
    #
    #   before-x   outside, before the whole element or call
    #   prepend-x  inside, before the content
    #   append-x   inside, after the content
    #   after-x    outside, after the whole element or call
    #
    # They work whether or not the caller also supplied the param itself, which
    # is the point: `<append-heading:>` alone has to add to the default heading.

    PSEUDO = %i[before prepend append after].freeze

    def pseudo(name, prefix)
      value = @params[:"#{prefix}_#{name}"]
      value && Parameter.wrap(value).content
    end

    def inner_pseudo?(name) = !!(pseudo(name, :prepend) || pseudo(name, :append))

    def around(name)
      return (yield; nil) if name.nil?
      pseudo(name, :before)&.call
      yield
      pseudo(name, :after)&.call
      nil
    end

    # `<page without-heading>` -- the extension point goes away entirely, and so
    # does anything the caller hung around it.
    def without?(name) = !!@without[:"without_#{name}"]

    # The parameter's content replaces the default, and the default is what
    # `old` reaches. A parameter with no content of its own -- one that only
    # carries attributes or nested params -- leaves the default alone.
    def render_content(name, parameter, &default)
      pseudo(name, :prepend)&.call
      if parameter&.content?
        Context.with(:old_stack => Context.old_stack + [default]) { parameter.content.call }
      else
        default&.call
      end
      pseudo(name, :append)&.call
      nil
    end

    # What a tag-call param wraps around: the content the call was already
    # given, or `old` -- which reaches whatever default the tag being called
    # declares for it.
    def call_default(parameter, supplied)
      return proc { old } unless supplied
      supplied = Parameter.wrap(supplied)
      # `merge_params` can hand a tag its own parameter back. Wrapping it around
      # itself would make `old` call the override again, for ever.
      return proc { old } if supplied.content.equal?(parameter&.content)
      supplied.content
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

end
