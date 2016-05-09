class TreeMap
  module Bound
    INCLUSIVE = 1
    EXCLUSIVE = 2
    NO_BOUND = 3
  end

  # A map with optional limits on its range.
  # This is intended to be used only by the TreeMap class.
  class BoundedMap
    include Enumerable

    attr_accessor :treemap, :ascending, :from, :from_bound, :to, :to_bound

    def initialize(treemap, ascending, from, from_bound, to, to_bound)
      @treemap = treemap
      @ascending = ascending
      @from = from
      @from_bound = from_bound
      @to = to
      @to_bound = to_bound

      # Validate the bounds. In addition to checking that from <= to, we verify that the comparator supports our bound objects.
      if from_bound != Bound::NO_BOUND && to_bound != Bound::NO_BOUND
        raise "Invalid from and to arguments: #{from} (from) > #{to} (to)" if comparator.call(from, to) > 0
      elsif from_bound != Bound::NO_BOUND
        comparator.call(from, from)
      elsif to_bound != Bound::NO_BOUND
        comparator.call(to, to)
      end
    end

    def empty?
      endpoint(true).nil?
    end

    def get(key)
      @treemap.get(key) if in_bounds?(key)
    end

    def contains_key?(key)
      in_bounds?(key) && @treemap.contains_key?(key)
    end

    def put(key, value)
      raise "Key out of bounds." unless in_bounds?(key)
      put_internal(key, value)
    end

    def remove(key)
      @treemap.remove(key) if in_bounds?(key)
    end

    # Returns true if the key is in bounds.
    # Note: The reference implementation calls this function isInBounds
    def in_bounds?(key)
      in_closed_bounds?(key, @from_bound, @to_bound)
    end

    # Returns true if the key is in bounds. Use this overload with
    # NO_BOUND to skip bounds checking on either end.
    # Note: The reference implementation calls this function isInBounds
    def in_closed_bounds?(key, from_bound, to_bound)
      if from_bound == Bound::INCLUSIVE
        return false if comparator.call(key, from) < 0      # less than from
      elsif from_bound == Bound::EXCLUSIVE
        return false if comparator.call(key, from) <= 0     # less than or equal to from
      end
      if to_bound == Bound::INCLUSIVE
        return false if comparator.call(key, to) > 0        # greater than 'to'
      elsif to_bound == Bound::EXCLUSIVE
        return false if comparator.call(key, to) >= 0       # greater than or equal to 'to'
      end
      true
    end

    # Returns the entry if it is in bounds, or null if it is out of bounds.
    def bound(node, from_bound, to_bound)
      node if node && in_closed_bounds?(node.key, from_bound, to_bound)
    end

    # Navigable methods

    def first_entry
      endpoint(true)
    end

    def poll_first_entry
      result = endpoint(true)
      @treemap.remove_internal(result) if result
      result
    end

    def first_key
      entry = endpoint(true)
      raise "No such element" unless entry
      entry.key
    end

    def last_entry
      endpoint(false)
    end

    def poll_last_entry
      result = endpoint(false)
      @treemap.remove_internal(result) if result
      result
    end

    def last_key
      entry = endpoint(false)
      raise "No such element" unless entry
      entry.key
    end

    # <first> - true for the first element, false for the last
    def endpoint(first)
      node, from, to = if @ascending == first
        node = case @from_bound
        when Bound::NO_BOUND
          @treemap.root.first if @treemap.root
        when Bound::INCLUSIVE
          @treemap.find(@from, Relation::CEILING)
        when Bound::EXCLUSIVE
          @treemap.find(@from, Relation::HIGHER)
        else
          raise "Undefined bound."
        end
        [node, Bound::NO_BOUND, @to_bound]
      else
        node = case @to_bound
        when Bound::NO_BOUND
          @treemap.root.last if @treemap.root
        when Bound::INCLUSIVE
          @treemap.find(@to, Relation::FLOOR)
        when Bound::EXCLUSIVE
          @treemap.find(@to, Relation::LOWER)
        else
          raise "Undefined bound."
        end
        [node, @from_bound, Bound::NO_BOUND]
      end
      bound(node, from, to)
    end

    # Performs a find on the underlying tree after constraining it to the
    # bounds of this view. Examples:
    #
    #   bound is (A..C)
    #   find_bounded(B, FLOOR) stays source.find(B, FLOOR)
    #
    #   bound is (A..C)
    #   find_bounded(C, FLOOR) becomes source.find(C, LOWER)
    #
    #   bound is (A..C)
    #   find_bounded(D, LOWER) becomes source.find(C, LOWER)
    #
    #   bound is (A..C]
    #   find_bounded(D, FLOOR) becomes source.find(C, FLOOR)
    #
    #   bound is (A..C]
    #   find_bounded(D, LOWER) becomes source.find(C, FLOOR)
    def find_bounded(key, relation)
      relation = Relation.for_order(relation, @ascending)
      from_bound_for_check = @from_bound
      to_bound_for_check = @to_bound
      if @to_bound != Bound::NO_BOUND && (relation == Relation::LOWER || relation == Relation::FLOOR)
        comparison = comparator.call(@to, key)
        if comparison <= 0
          key = @to
          if @to_bound == Bound::EXCLUSIVE
            relation = Relation::LOWER # 'to' is too high
          else comparison < 0
            relation = Relation::FLOOR # we already went lower
          end
        end
        to_bound_for_check = Bound::NO_BOUND # we've already checked the upper bound
      end
      if @from_bound != Bound::NO_BOUND && (relation == Relation::CEILING || relation == Relation::HIGHER)
        comparison = comparator.call(@from, key)
        if comparison >= 0
          key = @from
          if @from_bound == Bound::EXCLUSIVE
            relation = Relation::HIGHER # 'from' is too low
          else comparison > 0
            relation = Relation::CEILING # we already went higher
          end
        end
        from_bound_for_check = Bound::NO_BOUND # we've already checked the lower bound
      end
      bound(@treemap.find(key, relation), from_bound_for_check, to_bound_for_check)
    end

    def lower_entry(key)
      find_bounded(key, Relation::LOWER)
    end

    def lower_key(key)
      entry = find_bounded(key, Relation::LOWER)
      entry.key if entry
    end

    def floor_entry(key)
      find_bounded(key, Relation::FLOOR)
    end

    def floor_key(key)
      entry = find_bounded(key, Relation::FLOOR)
      entry.key if entry
    end

    def ceiling_entry(key)
      find_bounded(key, Relation::CEILING)
    end

    def ceiling_key(key)
      entry = find_bounded(key, Relation::CEILING)
      entry.key if entry
    end

    def higher_entry(key)
      find_bounded(key, Relation::HIGHER)
    end

    def higher_key(key)
      entry = find_bounded(key, Relation::HIGHER)
      entry.key if entry
    end

    def comparator
      if @ascending
        @treemap.comparator
      else
        ->(this, that) { -@treemap.comparator.call(this, that) }
      end
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

    def descending_map
      BoundedMap.new(@treemap, !@ascending, @from, @from_bound, @to, @to_bound)
    end

    # This can be called in 1 of 2 ways:
    # sub_map(from_inclusive, to_exclusive)
    # OR
    # sub_map(from, from_inclusive, to, to_inclusive)
    def sub_map(*args)
      case args.count
      when 2
        from_inclusive, to_exclusive = *args
        bounded_sub_map(from_inclusive, Bound::INCLUSIVE, to_exclusive, Bound::EXCLUSIVE)
      when 4
        from, from_inclusive, to, to_inclusive = *args
        from_bound = from_inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
        to_bound = to_inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
        bounded_sub_map(from, from_bound, to, to_bound)
      end
    end

    def bounded_sub_map(from, from_bound, to, to_bound)
      if !@ascending
        from, to = to, from
        from_bound, to_bound = to_bound, from_bound
      end

      # If both the current and requested bounds are exclusive, the isInBounds check must be
      # inclusive. For example, to create (C..F) from (A..F), the bound 'F' is in bounds.
      if from_bound == Bound::NO_BOUND
        from = @from
        from_bound = @from_bound
      else
        from_bound_to_check = from_bound == @from_bound ? Bound::INCLUSIVE : @from_bound
        raise out_of_bounds(to, from_bound_to_check, @to_bound) if !in_closed_bounds?(from, from_bound_to_check, @to_bound)
      end
      if to_bound == Bound::NO_BOUND
        to = @to
        to_bound = @to_bound
      else
        to_bound_to_check = to_bound == @to_bound ? Bound::INCLUSIVE : @to_bound
        raise out_of_bounds(to, @from_bound, to_bound_to_check) if !in_closed_bounds?(to, @from_bound, to_bound_to_check)
      end
      BoundedMap.new(@treemap, ascending, from, from_bound, to, to_bound)
    end

    # This can be called in 1 of 2 ways:
    # head_map(to_exclusive)
    # OR
    # head_map(to, inclusive)
    def head_map(*args)
      case args.count
      when 1
        to_exclusive = args.first
        bounded_sub_map(nil, Bound::NO_BOUND, to_exclusive, Bound::EXCLUSIVE)
      when 2
        to, inclusive = *args
        to_bound = inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
        bounded_sub_map(nil, Bound::NO_BOUND, to, to_bound)
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
        bounded_sub_map(fromInclusive, Bound::INCLUSIVE, nil, Bound::NO_BOUND)
      when 2
        from, inclusive = *args
        from_bound = inclusive ? Bound::INCLUSIVE : Bound::EXCLUSIVE
        bounded_sub_map(from, from_bound, nil, Bound::NO_BOUND)
      end
    end

    def out_of_bounds(value, from_bound, to_bound)
      Exception.new("#{value} not in range #{from_bound.left_cap(@from)}..#{to_bound.right_cap(@to)}")
    end

    # Bounded view implementations

    # in-order traversal of nodes in tree
    class BoundedNodeIterator < ::TreeMap::NodeIterator
      def initialize(bounded_map, next_node)
        super(next_node)
        @bounded_map = bounded_map
      end

      def step_forward
        result = super
        @next_node = nil if @next_node && !@bounded_map.in_closed_bounds?(@next_node.key, Bound::NO_BOUND, @bounded_map.to_bound)
        result
      end

      def step_backward
        result = super
        @next_node = nil if @next_node && !@bounded_map.in_closed_bounds?(@next_node.key, @bounded_map.from_bound, Bound::NO_BOUND)
        result
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
        iter = BoundedNodeIterator.new(self, endpoint(true))
        while iter.has_next?
          yield iter.step_forward()
        end
      else
        enum_for(:each_node)
      end
    end

  end
end
