module Rapid

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

end
