$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

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

    assert_equal(1, m.first_key)
    assert_equal(100, m.last_key)

    assert_equal(nil, m.lower_key(0))
    assert_equal(nil, m.floor_key(0))
    assert_equal(1, m.ceiling_key(0))
    assert_equal(1, m.higher_key(0))

    assert_equal(nil, m.lower_key(1))
    assert_equal(1, m.floor_key(1))

    assert_equal(1, m.lower_key(10))
    assert_equal(10, m.floor_key(10))
    assert_equal(10, m.ceiling_key(10))
    assert_equal(100, m.higher_key(10))

    assert_equal(100, m.ceiling_key(100))
    assert_equal(nil, m.higher_key(100))

    assert_equal(100, m.lower_key(500))
    assert_equal(100, m.floor_key(500))
    assert_equal(nil, m.ceiling_key(500))
    assert_equal(nil, m.higher_key(500))
  end

  def test_tree_map_empty_iteration
    TreeMap.new.each { fail }
  end

  def test_bounded_map
    m = TreeMap.new

    m.put(0, "a")
    m.put(10, "b")
    m.put(20, "c")
    m.put(30, "d")
    m.put(40, "e")
    m.put(50, "f")
    m.put(60, "g")
    m.put(70, "h")
    m.put(80, "i")
    m.put(90, "j")
    m.put(100, "k")

    hm1 = m.head_map(30)
    assert_equal(hm1.to_a, [[0,"a"], [10, "b"], [20, "c"]])

    hm2 = m.head_map(30, true)
    assert_equal(hm2.to_a, [[0,"a"], [10, "b"], [20, "c"], [30, "d"]])

    tm1 = m.tail_map(80)
    assert_equal(tm1.to_a, [[80,"i"], [90, "j"], [100, "k"]])

    tm2 = m.tail_map(80, false)
    assert_equal(tm2.to_a, [[90, "j"], [100, "k"]])

    sm1 = m.sub_map(30, 50)
    assert_equal(sm1.to_a, [[30, "d"], [40, "e"]])

    sm2 = m.sub_map(30, false, 50, true)
    assert_equal(sm2.to_a, [[40, "e"], [50, "f"]])
  end
end
