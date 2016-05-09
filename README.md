# treemap

A Ruby port of the Android implementation of Java's java.util.TreeMap class.

This is an AVL tree based implementation of Java's java.util.TreeMap structure.

It implements Java's java.util.NavigableMap interface.


### References:
- Reference java implementation: https://android.googlesource.com/platform/libcore.git/+/android-6.0.1_r32/luni/src/main/java/java/util/TreeMap.java


### Install
```
gem install treemap
```


### Usage
In IRB (some lines elided):
```
irb(main):001:0> require 'treemap'
=> true
irb(main):002:0> m = TreeMap.new; nil
=> nil
irb(main):003:0> m.put(1, "foo")
=> nil
irb(main):004:0> m.put(100, "baz")
=> nil
irb(main):005:0> m.put(10, "bar")
=> nil
irb(main):006:0> m.each {|k, v| puts "#{k} -> #{v}" }
1 -> foo
10 -> bar
100 -> baz
=> nil
irb(main):007:0> m.to_a
=> [[1, "foo"], [10, "bar"], [100, "baz"]]
irb(main):008:0> m.keys
=> #<Set: {1, 10, 100}>
irb(main):009:0> m.values
=> ["foo", "bar", "baz"]
irb(main):010:0> m.first_key
=> 1
irb(main):011:0> m.last_key
=> 100
irb(main):012:0> m.lower_key(10)
=> 1
irb(main):013:0> m.floor_key(10)
=> 10
irb(main):014:0> m.ceiling_key(10)
=> 10
irb(main):015:0> m.higher_key(10)
=> 100
```


### Run Tests:
```
rake
```
OR
```
rake test
```
