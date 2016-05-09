Gem::Specification.new do |s|
  s.name        = 'treemap'
  s.version     = '1.0.3'
  s.date        = '2016-05-05'
  s.summary     = "TreeMap is a Ruby port of the Android implementation of Java's java.util.TreeMap class."
  s.description = <<-DESC
    A Ruby port of the Android implementation of Java's java.util.TreeMap class.
    This is an AVL tree based implementation of Java's java.util.TreeMap structure.
    It implements Java's java.util.NavigableMap interface.
    The reference implementation is at https://android.googlesource.com/platform/libcore.git/+/android-6.0.1_r32/luni/src/main/java/java/util/TreeMap.java
  DESC
  s.authors     = ["David Ellis"]
  s.email       = "davidkellis@gmail.com"
  s.files       = ["lib/treemap.rb", "lib/treemap/tree_map.rb", "lib/treemap/bounded_map.rb"]
  s.homepage    = "https://github.com/davidkellis/treemap"
  s.license     = "MIT"
end
