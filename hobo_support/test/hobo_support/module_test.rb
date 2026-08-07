require "test_helper"

# Ported from test/hobosupport/module.rdoctest. The original callback example
# used alias_method_chain, which Rails removed in 5.1; the mechanism under test
# is the callback itself, so it is exercised with a plain alias.
class ModuleTest < Minitest::Test

  def test_included_in_class_callbacks_reaches_the_nested_module
    shouting = Module.new do
      def self.included_in_class(klass)
        klass.singleton_class.class_eval do
          alias_method :quiet_label, :label
          def label; quiet_label.upcase; end
        end
      end
    end

    outer = Module.new do
      define_singleton_method(:included) { |base| base.send(:included_in_class_callbacks, base) }
      include shouting
    end

    klass = Class.new do
      def self.label; "my name is C"; end
    end
    klass.include(outer)

    assert_equal "MY NAME IS C", klass.label
  end

  def test_inheriting_cattr_reader_falls_back_to_the_superclass
    parent = Class.new { inheriting_cattr_reader :nickname => "Andy" }
    child  = Class.new(parent)

    assert_equal "Andy", parent.nickname
    assert_equal "Andy", child.nickname
  end

  def test_inheriting_cattr_reader_lets_the_subclass_override_without_touching_the_parent
    parent = Class.new { inheriting_cattr_reader :nickname => "Andy" }
    child  = Class.new(parent)
    child.instance_variable_set(:@nickname, "Bob")

    assert_equal "Bob",  child.nickname
    assert_equal "Andy", parent.nickname
  end

  def test_classy_module_class_evals_its_whole_body
    mod = classy_module do
      def self.foo; 123; end
    end

    assert_equal Module, mod.class

    klass = Class.new { include mod }
    assert_equal 123, klass.foo
  end

end
