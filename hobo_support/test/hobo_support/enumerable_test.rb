require "test_helper"

# Ported from test/hobosupport/enumerable.rdoctest. The `.*.`, `where` and
# `where_not` sections are gone with the operators themselves, and `drop_while`
# and `take_while` are plain Ruby now.
class EnumerableTest < Minitest::Test

  def test_map_and_find_returns_the_first_truthy_result_of_the_block
    assert_equal 4, %w(my name is Fred).map_and_find { |s| s.length if s =~ /^[A-Z]/ }
  end

  def test_map_and_find_returns_the_fallback_when_the_block_never_returns_a_value
    assert_equal "Foo",
                 %w(my name is not available).map_and_find("Foo") { |s| s.length if s =~ /^[A-Z]/ }
  end

  def test_map_with_index_passes_the_element_and_its_index
    assert_equal ["", "short", "wordswords"],
                 %w(some short words).map_with_index { |s, i| s * i }
  end

  def test_build_hash_skips_the_elements_for_which_the_block_returns_nil
    assert_equal({ "some" => 4, "words" => 5 },
                 %w(some short words).build_hash { |s| [s, s.length] unless s == "short" })
  end

  def test_map_hash_keys_by_element_and_values_by_block
    assert_equal({ "some" => 4, "short" => 5, "words" => 5 },
                 %w(some short words).map_hash { |s| s.length })
  end

  def test_rest_drops_the_first_element
    assert_equal ["short", "words"], %w(some short words).rest
  end

  def test_in_p
    assert 3.in?(0..10)
    refute 300.in?(0..10)
  end

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
