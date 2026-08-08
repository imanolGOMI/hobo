require "test_helper"

# Ported from test/hobosupport.rdoctest. Its `._?` and `try.` sections went away
# with the operators; `try(:method)` is ActiveSupport's now.
class ObjectTest < Minitest::Test

  def test_is_one_of_checks_several_types_at_once
    assert "foo".is_one_of?(String, Symbol)
    assert :foo.is_one_of?(String, Symbol)
    refute 1.is_one_of?(String, Symbol)
  end

  def test_active_support_try_replaces_the_old_power_dot
    assert_equal "oof", "foo".try(:reverse)
    assert_nil :foo.try(:reverse)
    assert_nil nil.try(:reverse)
  end

end
