require 'minitest/autorun'
require 'treemap'
require 'set'

class TreeMapTest < Minitest::Test
  def test_tree_map
    m = TreeMap.new

    m.put(1, "foo")
    m.put(100, "baz")
    m.put(10, "bar")

    # m.each {|k, v| puts "#{k} -> #{v}" }
    # puts m.to_a.inspect
    assert_equal(m.to_a, [[1,"foo"], [10, "bar"], [100, "baz"]])

    assert_equal(nil, m[0])
    assert_equal("foo", m[1])
    assert_equal("bar", m[10])
    assert_equal("baz", m[100])

    assert_equal(Set.new([1,10,100]), m.keys)
    assert_equal(["foo", "bar", "baz"], m.values)
  end
end
