require "test_helper"

# Ported from test/hobosupport/hash.rdoctest.
class HashTest < Minitest::Test

  def test_select_hash_with_a_two_argument_block
    assert_equal({ 1 => 2, 3 => 4 },
                 { 1 => 2, 3 => 4, 6 => 5 }.select_hash { |key, value| key < value })
  end

  def test_select_hash_with_a_one_argument_block_receives_the_value
    assert_equal({ 3 => 4, 6 => 5 },
                 { 1 => 2, 3 => 4, 6 => 5 }.select_hash { |value| value != 2 })
  end

  def test_map_hash_with_a_two_argument_block
    assert_equal({ 1 => true, 3 => true, 6 => false },
                 { 1 => 2, 3 => 4, 6 => 5 }.map_hash { |key, value| key < value })
  end

  def test_map_hash_with_a_one_argument_block_receives_the_value
    assert_equal({ 1 => 200, 3 => 400, 6 => 500 },
                 { 1 => 2, 3 => 4, 6 => 5 }.map_hash { |value| value * 100 })
  end

  def test_partition_hash_by_keys
    assert_equal [{ 1 => 2, 3 => 4 }, { 6 => 5 }],
                 { 1 => 2, 3 => 4, 6 => 5 }.partition_hash([1, 3])
  end

  def test_partition_hash_by_block
    assert_equal [{ 1 => 2, 3 => 4 }, { 6 => 5 }],
                 { 1 => 2, 3 => 4, 6 => 5 }.partition_hash { |key, value| key < value }
  end

  def test_recursive_update_merges_sub_hashes_instead_of_overwriting_them
    hash = { :a => 1, :b => { :x => 10 } }
    hash.recursive_update({ :c => 3, :b => { :y => 20 } })
    assert_equal({ :a => 1, :b => { :x => 10, :y => 20 }, :c => 3 }, hash)
  end

  def test_minus_removes_the_pairs_whose_key_is_in_the_array
    assert_equal({ 6 => 5 }, { 1 => 2, 3 => 4, 6 => 5 } - [1, 3])
  end

  def test_ampersand_keeps_only_the_pairs_whose_key_is_in_the_array
    assert_equal({ 1 => 2, 3 => 4 }, { 1 => 2, 3 => 4, 6 => 5 } & [1, 3])
  end

  def test_pipe_is_an_alias_for_merge
    assert_equal({ 1 => 3, 2 => 4 }, { 1 => 2 } | { 1 => 3, 2 => 4 })
  end

  def test_get_returns_the_values_for_the_given_keys
    assert_equal [2, 4], { 1 => 2, 3 => 4, 6 => 5 }.get(1, 3)
  end

  def test_compact_drops_the_pairs_whose_value_is_nil
    assert_equal({ 1 => "a", 3 => "b" }, { 1 => "a", 2 => nil, 3 => "b" }.compact)
  end

  def test_compact_bang_drops_the_pairs_whose_value_is_nil_in_place
    hash = { 1 => "a", 2 => nil, 3 => "b" }
    hash.compact!
    assert_equal({ 1 => "a", 3 => "b" }, hash)
  end

end
