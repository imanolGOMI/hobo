require "test_helper"

# What survives of test/hobosupport/hash.rdoctest. The rest of that file tested
# helpers that core Ruby has since grown: select_hash (Hash#select), map_hash
# (transform_values), - (except), & (slice), get (values_at), compact, | (merge)
# and recursive_update (ActiveSupport's deep_merge!).
class HashTest < Minitest::Test

  def test_partition_hash_by_keys
    assert_equal [{ 1 => 2, 3 => 4 }, { 6 => 5 }],
                 { 1 => 2, 3 => 4, 6 => 5 }.partition_hash([1, 3])
  end

  def test_partition_hash_by_block
    assert_equal [{ 1 => 2, 3 => 4 }, { 6 => 5 }],
                 { 1 => 2, 3 => 4, 6 => 5 }.partition_hash { |key, value| key < value }
  end

  def test_partition_hash_normalises_symbol_keys_on_indifferent_hashes
    hash = ActiveSupport::HashWithIndifferentAccess.new(:a => 1, :b => 2)

    assert_equal [{ "a" => 1 }, { "b" => 2 }],
                 hash.partition_hash([:a]).map(&:to_h)
  end

  def test_partition_hash_with_no_keys_on_an_indifferent_hash
    hash = ActiveSupport::HashWithIndifferentAccess.new(:a => 1, :b => 2)

    assert_equal [{ "a" => 1 }, { "b" => 2 }],
                 hash.partition_hash { |key, _| key == "a" }.map(&:to_h)
  end

end
