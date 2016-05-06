require 'pp'

# TreeMap is a Ruby port of https://android.googlesource.com/platform/libcore.git/+/android-6.0.1_r32/luni/src/main/java/java/util/TreeMap.java
class TreeMap
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
    def next
      if @right
        right.first
      else
        node = self
        parent = node.parent
        while parent
          if parent.left == node
            return parent
          end
          node = parent
          parent = node.parent
        end
      end
      nil
    end

    # Returns the previous node in an inorder traversal, or null if this is the first node in the tree.
    def prev
      if @left
        left.last
      else
        node = self
        parent = node.parent
        while parent
          if parent.right == node
            return parent
          end
          node = parent
          parent = node.parent
        end
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

  attr_accessor :size

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

  def contains_key?(key)
    find_by_object(key)
  end

  def put(k, v)
    put_internal(k, v)
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

  def put_internal(k, v)
    created = find(k, Relation::CREATE)
    result = created.value
    created.value = v
    result
  end

  def find(key, relation)
    # todo, finish this
  end
end
