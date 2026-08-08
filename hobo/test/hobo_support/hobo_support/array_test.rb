require "test_helper"

# The destructive drop_while, from test/hobosupport/enumerable.rdoctest. Its
# non-destructive counterpart, and take_while, are plain Ruby now.
class ArrayTest < Minitest::Test

  def test_drop_while_bang_drops_the_leading_elements_in_place
    words = %w(this is a nice example)
    words.drop_while! { |s| s.length > 1 }

    assert_equal ["a", "nice", "example"], words
  end

  def test_multiply_with_an_argument_still_joins
    assert_equal "1,2,3", [1, 2, 3] * ","
  end

  def test_multiply_with_an_integer_still_repeats
    assert_equal [1, 2, 1, 2], [1, 2] * 2
  end

end
