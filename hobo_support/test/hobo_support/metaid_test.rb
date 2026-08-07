require "test_helper"

# Ported from test/hobosupport/metaid.rdoctest.
class MetaidTest < Minitest::Test

  def test_metaclass_returns_the_singleton_class
    object = Object.new
    def object.foo; 123; end

    assert_equal 123, object.foo
    assert object.metaclass.method_defined?(:foo)
  end

  # meta_eval instance_evals the metaclass, so the body has to *call* something
  # on it -- alias_method here -- rather than use def, which would land on the
  # metaclass of the metaclass.
  def test_meta_eval_evaluates_a_string_in_the_metaclass
    klass = Class.new { def self.original; :ok; end }
    klass.meta_eval "alias_method :aliased_by_string, :original"

    assert_equal :ok, klass.aliased_by_string
  end

  def test_meta_eval_evaluates_a_block_in_the_metaclass
    klass = Class.new { def self.original; :ok; end }
    klass.meta_eval { alias_method :aliased_by_block, :original }

    assert_equal :ok, klass.aliased_by_block
  end

  def test_metaclass_eval_class_evals_a_string
    klass = Class.new(String)
    klass.metaclass_eval "def with_argument(value); value; end"

    assert_equal "b", klass.with_argument("b")
  end

  def test_metaclass_eval_class_evals_a_block
    klass = Class.new(String)
    klass.metaclass_eval { def with_argument_from_block(value); value; end }

    assert_equal "b", klass.with_argument_from_block("b")
  end

  def test_meta_def_defines_a_class_method_from_a_block
    klass = Class.new(String)
    klass.meta_def(:backwards) { |s| s.reverse }

    assert_equal "egnarts", klass.backwards("strange")
  end

end
