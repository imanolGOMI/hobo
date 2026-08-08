require "test_helper"

# Ported from test/hobosupport/implies.rdoctest.
class ImpliesTest < Minitest::Test

  def test_a_false_premise_implies_anything
    assert_equal true, false.implies(true)
    assert_equal true, false.implies(false)
  end

  def test_a_true_premise_implies_only_a_true_conclusion
    assert_equal true,  true.implies(true)
    assert_equal false, true.implies(false)
  end

end
