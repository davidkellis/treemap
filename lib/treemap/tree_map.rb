require 'pp'
require 'set'

# TreeMap is a Ruby port of https://android.googlesource.com/platform/libcore.git/+/android-6.0.1_r32/luni/src/main/java/java/util/TreeMap.java
# This is an AVL tree based implementation of Java's java.util.TreeMap structure.
# It implements Java's java.util.NavigableMap interface.
# Warning: Not all of the reference implementation has been ported.
class TreeMap
  include Enumerable

  module Relation
    LOWER = 1
    FLOOR = 2
    EQUAL = 3
    CREATE = 4
    CEILING = 5
    HIGHER = 6

    def self.for_order(relation, ascending)
      if ascending
        relation
      else
        case relation
        when LOWER
          HIGHER
        when FLOOR
          CEILING
        when EQUAL
          EQUAL
        when CEILING
          FLOOR
        when HIGHER
          LOWER
        else
          raise "Unknown relation: #{relation.inspect}"
        end
      end
    end
  end

  class Node
    attr_accessor :parent, :left, :right, :key, :value, :height

    def initialize(parent, key)
      @parent = parent
      @left = nil
      @right = nil
      @key = key
      @value = nil
      @height = 1
    end

    def copy(parent)
      result = Node.new(@parent, @key)
      if @left
        result.left = @left.copy(result)
      end
      if @right
        result.right = @right.copy(result)
      end
      result.value = @value
      result.height = @height
      result
    end

    def set_value(new_value)
        old_value = @value
        @value = new_value
        old_value
    end

    def ==(other)
      if other.is_a?(Node)
        @key == other.key && @value == other.value
      else
        false
      end
    end

    alias eql? ==

    def hash
      (key.nil? ? 0 : key.hash) ^ (value.nil? ? 0 : value.hash)
    end

    def to_s
      "#{@key}=#{@value}"
    end

    # Returns the next node in an inorder traversal, or null if this is the last node in the tree.
    def next_node
      return @right.first if @right

      node = self
      parent = node.parent
      while parent
        if parent.left == node
          return parent
        end
        node = parent
        parent = node.parent
      end
      nil
    end

    # Returns the previous node in an inorder traversal, or null if this is the first node in the tree.
    def prev_node
      return @left.last if @left

      node = self
      parent = node.parent
      while parent
        if parent.right == node
          return parent
        end
        node = parent
        parent = node.parent
      end
      nil
    end

    # Returns the first node in this subtree.
    def first
      node = self
      child = node.left
      while child
        node = child
        child = node.left
      end
      node
    end

    # Returns the last node in this subtree.
    def last
      node = self
      child = node.right
      while child
        node = child
        child = node.right
      end
      node
    end
  end

  NaturalOrder = ->(this, that) { this <=> that }

  attr_accessor :comparator, :root, :size

  # comparator is a function of the form: (this, that) -> int ; where int is -1 if this < that, 0 if this == that, and 1 if this > that
  def initialize(comparator = NaturalOrder)
    @comparator = comparator
    @root = nil
    @size = 0
    @mod_count = 0
  end

  def empty?
    @size == 0
  end

  def get(key)
    entry = find_by_object(key)
    entry.value if entry
  end

  alias [] get

  def contains_key?(key)
    find_by_object(key)
  end

  def put(key, value)
    put_internal(key, value)
  end

  def clear
    @root = nil
    @size = 0
    @mod_count += 1
  end

  def remove(key)
    node = remove_internal_by_key(key)
    node.value if node
  end

  def put_internal(key, value)
    created = find(key, Relation::CREATE)
    result = created.value
    created.value = value
    result
  end

  # Returns the node at or adjacent to the given key, creating it if requested.
  def find(key, relation)
    if @root.nil?
      if relation == Relation::CREATE
        @root = Node.new(nil, key)
        @size = 1
        @mod_count += 1
        return @root
      else
        return nil
      end
    end

    nearest = @root
    while true
      comparison = @comparator.call(key, nearest.key)

      # we found the requested key
      if comparison == 0
        case relation
        when Relation::LOWER
          return nearest.prev_node
        when Relation::FLOOR, Relation::EQUAL, Relation::CREATE, Relation::CEILING
          return nearest
        when Relation::HIGHER
          return nearest.next_node
        end
      end

      child = (comparison < 0) ? nearest.left : nearest.right
      if child
        nearest = child
        next  # continue
      end

      # We found a nearest node. Every key not in the tree has up to two nearest nodes, one lower and one higher.
      if comparison < 0     # nearest.key is higher
        case relation
        when Relation::LOWER, Relation::FLOOR
          return nearest.prev_node
        when Relation::CEILING, Relation::HIGHER
          return nearest
        when Relation::EQUAL
          return nil
        when Relation::CREATE
          created = Node.new(nearest, key)
          nearest.left = created
          @size += 1
          @mod_count += 1
          rebalance(nearest, true)
          return created
        end
      else                  # comparison > 0 ; nearest.key is lower
        case relation
        when Relation::LOWER, Relation::FLOOR
          return nearest
        when Relation::CEILING, Relation::HIGHER
          return nearest.next_node
        when Relation::EQUAL
          return nil
        when Relation::CREATE
          created = Node.new(nearest, key)
          nearest.right = created
          @size += 1
          @mod_count += 1
          rebalance(nearest, true)
          return created
        end
      end
    end
  end

  # returns a Node
  def find_by_object(key)
    find(key, Relation::EQUAL)
  end

  # entry is a key-value pair in an array: [key, value]
  # Returns this map's entry that has the same key and value as <entry>, or null if this map has no such entry.
  #
  # This method uses the comparator for key equality rather than <equals>. If this map's comparator isn't consistent with equals,
  # then {@code remove()} and {@code contains()} will violate the collections API.
  #
  # returns a Node
  def find_by_entry(key, value)
    key, value = *entry
    mine = find_by_object(key)
    mine if mine && mine.value == value
  end

  # Removes {@code node} from this tree, rearranging the tree's structure as necessary.
  # return value not meaningful
  def remove_internal(node)
    left = node.left
    right = node.right
    original_parent = node.parent

    if left && right
      # To remove a node with both left and right subtrees, move an adjacent node from one of those subtrees into this node's place.
      # Removing the adjacent node may change this node's subtrees. This node may no longer have two subtrees once the adjacent node is gone!

      adjacent = left.height > right.height ? left.last : right.first
      remove_internal(adjacent)   # takes care of rebalance and size--

      left_height = 0
      left = node.left
      if left
        left_height = left.height
        adjacent.left = left
        left.parent = adjacent
        node.left = nil
      end
      right_height = 0
      right = node.right
      if right
        right_height = right.height
        adjacent.right = right
        right.parent = adjacent
        node.right = nil
      end
      adjacent.height = [left_height, right_height].max + 1
      replace_in_parent(node, adjacent)
      return
    elsif left
      replace_in_parent(node, left)
      node.left = nil
    elsif right
      replace_in_parent(node, right)
      node.right = nil
    else
      replace_in_parent(node, nil)
    end

    rebalance(original_parent, false)
    @size -= 1
    @mod_count -= 1
  end

  def remove_internal_by_key(key)
    node = find_by_object(key)
    if node
      remove_internal(node)
    end
    node
  end

  def replace_in_parent(node, replacement)
    parent = node.parent
    node.parent = nil
    if replacement
      replacement.parent = parent
    end

    if parent
      if parent.left == node
        parent.left = replacement
      else
        # assert (parent.right == node)
        parent.right = replacement
      end
    else
      @root = replacement
    end
  end

  # Rebalances the tree by making any AVL rotations necessary between the newly-unbalanced node and the tree's root.
  #
  # @param insert true if the node was unbalanced by an insert; false if it was by a removal.
  def rebalance(unbalanced, insert)
    node = unbalanced
    while node
      left = node.left
      right = node.right
      left_height = left ? left.height : 0
      right_height = right ? right.height : 0

      delta = left_height - right_height
      if delta == -2
        right_left = right.left
        right_right = right.right
        right_right_height = right_right ? right_right.height : 0
        right_left_height = right_left ? right_left.height : 0

        right_delta = right_left_height - right_right_height
        if right_delta == -1 || (right_delta == 0 && !insert)
          rotate_left(node)
        else
          # assert (right_delta == 1)
          rotate_right(right)   # AVL right left
          rotate_left(node)
        end
        break if insert   # no further rotations will be necessary
      elsif delta == 2
        left_left = left.left
        left_right = left.right
        left_right_height = left_right ? left_right.height : 0
        left_left_height = left_left ? left_left.height : 0

        left_delta = left_left_height - left_right_height
        if left_delta == 1 || (left_delta == 0 && !insert)
          rotate_right(node)    # AVL left left
        else
          # assert (left_delta == -1)
          rotate_left(left)   # AVL left right
          rotate_right(node)
        end
        break if insert
      elsif delta == 0
        node.height = left_height + 1   # left_height == right_height
        break if insert
      else
        # assert (delta == -1 || delta == 1)
        node.height = [left_height, right_height].max + 1
        break if insert    # the height hasn't changed, so rebalancing is done!
      end

      node = node.parent
    end
  end

  # Rotates the subtree so that its root's right child is the new root
  def rotate_left(root)
    left = root.left
    pivot = root.right
    pivot_left = pivot.left
    pivot_right = pivot.right

    # move the pivot's left child to the root's right
    root.right = pivot_left
    if pivot_left
      pivot_left.parent = root
    end

    replace_in_parent(root, pivot)

    # move the root to the pivot's left
    pivot.left = root
    root.parent = pivot

    # fix heights
    root.height = [left ? left.height : 0, pivot_left ? pivot_left.height : 0].max + 1
    pivot.height = [root.height, pivot_right ? pivot_right.height : 0].max + 1
  end

  # Rotates the subtree so that its root's left child is the new root
  def rotate_right(root)
    pivot = root.left
    right = root.right
    pivot_left = pivot.left
    pivot_right = pivot.right

    # move the pivot's right child to the root's left
    root.left = pivot_right
    if pivot_right
      pivot_right.parent = root
    end

    replace_in_parent(root, pivot)

    # move the root to the pivot's right
    pivot.right = root
    root.parent = pivot

    # fix heights
    root.height = [right ? right.height : 0, pivot_right ? pivot_right.height : 0].max + 1
    pivot.height = [root.height, pivot_left ? pivot_left.height : 0].max + 1
  end

  # Navigable Methods

  # Returns a key-value mapping associated with the least key in this map, or null if the map is empty.
  def first_entry
    root.first if root
  end

  def internal_poll_first_entry
    if root
      result = root.first
      remove_internal(result)
      result
    end
  end

  def poll_first_entry
    internal_poll_first_entry
  end

  def first_key
    raise "No such element." unless root
    root.first.key
  end

  # Returns a key-value mapping associated with the greatest key in this map, or null if the map is empty.
  def last_entry
    root.last if root
  end

  def internal_poll_last_entry
    if root
      result = root.last
      remove_internal(result)
      result
    end
  end

  def poll_last_entry
    internal_poll_last_entry
  end

  def last_key
    raise "No such element." unless root
    root.last.key
  end

  # Returns a key-value mapping associated with the greatest key strictly less than the given key, or null if there is no such key.
  def lower_entry(key)
    find(key, Relation::LOWER)
  end

  # Returns the greatest key strictly less than the given key, or null if there is no such key.
  def lower_key(key)
    entry = find(key, Relation::LOWER)
    entry.key if entry
  end

  # Returns a key-value mapping associated with the greatest key less than or equal to the given key, or null if there is no such key.
  def floor_entry(key)
    find(key, Relation::FLOOR)
  end

  # Returns the greatest key less than or equal to the given key, or null if there is no such key.
  def floor_key(key)
    entry = find(key, Relation::FLOOR)
    entry.key if entry
  end

  # Returns a key-value mapping associated with the least key greater than or equal to the given key, or null if there is no such key.
  def ceiling_entry(key)
    find(key, Relation::CEILING)
  end

  # Returns the least key greater than or equal to the given key, or null if there is no such key.
  def ceiling_key(key)
    entry = find(key, Relation::CEILING)
    entry.key if entry
  end

  # Returns a key-value mapping associated with the least key strictly greater than the given key, or null if there is no such key.
  def higher_entry(key)
    find(key, Relation::HIGHER)
  end

  # Returns the least key strictly greater than the given key, or null if there is no such key.
  def higher_key(key)
    entry = find(key, Relation::HIGHER)
    entry.key if entry
  end

  # View factory methods

  def entry_set
    Set.new(each_node.to_a)
  end

  def key_set
    Set.new(each_node.map(&:key))
  end

  alias keys key_set

  def values
    each_node.map(&:value)
  end

  # This can be called in 1 of 2 ways:
  # sub_map(from_inclusive, to_exclusive)
  # OR
  # sub_map(from, from_inclusive, to, to_inclusive)
  def sub_map(*args)
    case args.count
    when 2
      from_inclusive, to_exclusive = *args
      BoundedMap.new(self, true, from_inclusive, Bound::INCLUSIVE, to_exclusive, Bound::EXCLUSIVE)
    when 4
      from, from_inclusive, to, to_inclusive = *args
      from_bound = from_inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
      to_bound = to_inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
      BoundedMap.new(self, true, from, from_bound, to, to_bound);
    end
  end

  # This can be called in 1 of 2 ways:
  # head_map(to_exclusive)
  # OR
  # head_map(to, inclusive)
  def head_map(*args)
    case args.count
    when 1
      to_exclusive = args.first
      BoundedMap.new(self, true, nil, Bound::NO_BOUND, to_exclusive, Bound::EXCLUSIVE)
    when 2
      to, inclusive = *args
      to_bound = inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
      BoundedMap.new(self, true, nil, Bound::NO_BOUND, to, to_bound)
    end
  end

  # This can be called in 1 of 2 ways:
  # tail_map(from_inclusive)
  # OR
  # tail_map(from, inclusive)
  def tail_map(*args)
    case args.count
    when 1
      from_inclusive = args.first
      BoundedMap.new(self, true, from_inclusive, Bound::INCLUSIVE, nil, Bound::NO_BOUND)
    when 2
      from, inclusive = *args
      from_bound = inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
      BoundedMap.new(self, true, from, from_bound, nil, Bound::NO_BOUND)
    end
  end

  def descending_map
    BoundedMap.new(self, false, nil, Bound::NO_BOUND, nil, Bound::NO_BOUND)
  end

  # Tree traversal methods

  # in-order traversal of nodes in tree
  class NodeIterator
    def initialize(next_node)
      @next_node = next_node
      @last_node = nil
    end

    def has_next?
      !!@next_node
    end

    def step_forward
      if @next_node
        @last_node = @next_node
        @next_node = @next_node.next_node
        @last_node
      end
    end

    def step_backward
      if @next_node
        @last_node = @next_node
        @next_node = @next_node.prev_node
        @last_node
      end
    end
  end

  # each {|k,v| puts "#{k}->#{v}"}
  def each(&blk)
    if block_given?
      each_node {|node| blk.call(node.key, node.value) }
    else
      enum_for(:each)
    end
  end

  # each_node {|node| puts "#{node.key}->#{node.value}"}
  def each_node
    if block_given?
      iter = NodeIterator.new(empty? ? nil : @root.first)
      while iter.has_next?
        yield iter.step_forward()
      end
    else
      enum_for(:each_node)
    end
  end
end
