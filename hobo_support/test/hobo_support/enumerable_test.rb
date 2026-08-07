require "test_helper"

# What survives of test/hobosupport/enumerable.rdoctest. Gone with the pruning:
# the `.*.`, `where` and `where_not` operators, plus map_hash (Rails'
# index_with), rest (drop(1)), map_with_index (map.with_index) and build_hash
# (filter_map { }.to_h).
class EnumerableTest < Minitest::Test

  def test_map_and_find_returns_the_first_truthy_result_of_the_block
    assert_equal 4, %w(my name is Fred).map_and_find { |s| s.length if s =~ /^[A-Z]/ }
  end

  def test_map_and_find_returns_the_fallback_when_the_block_never_returns_a_value
    assert_equal "Foo",
                 %w(my name is not available).map_and_find("Foo") { |s| s.length if s =~ /^[A-Z]/ }
  end

  def test_map_and_find_stops_at_the_first_hit
    seen = []
    %w(my name is Fred).map_and_find { |s| seen << s; s.length if s =~ /^[A-Z]/ }

    assert_equal %w(my name is Fred), seen
  end

  def test_in_p
    assert 3.in?(0..10)
    refute 300.in?(0..10)
  end

  # ActiveSupport's in? raises ArgumentError here; ours does not.
  def test_in_p_treats_nil_as_an_empty_enumeration
    refute 3.in?(nil)
  end

  def test_not_in_p
    refute 3.not_in?(0..10)
    assert 300.not_in?(0..10)
  end

  def test_not_in_p_treats_nil_as_an_empty_enumeration
    assert 3.not_in?(nil)
  end

end
