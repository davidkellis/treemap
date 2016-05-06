require 'minitest/autorun'
require 'treemap'

class TreeMapTest < Minitest::Test
  def test_tree_map
    m = TreeMap.new
    m.put(1, "foo")
    m.put(2, "bar")
    m.put(3, "baz")
    # assert_equal(?, ?)
  end
end
