module Rapid

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
          { :buffer => nil, :this => nil, :this_parent => nil, :this_field => nil,
            :scope => Scope.new, :old_stack => [] }
      end

      def buffer      = state[:buffer]
      def this        = state[:this]

      # `this` is not just a value: it is a value **and where it came from**.
      # Without the parent record and the field name, a tag cannot tell the
      # declared type of a nil, cannot ask whether the field may be viewed, and
      # cannot name the css class of what it is painting. DRYML kept the same
      # three together, saved and restored as one.
      def this_parent = state[:this_parent]
      def this_field  = state[:this_field]
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

end
