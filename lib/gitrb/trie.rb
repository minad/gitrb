module Gitrb
  class Trie
    include Enumerable

    attr_reader :key, :value

    def initialize(key = nil, value = nil, children = [])
      @key = key
      @value = value
      @children = children
    end

    def children
      @children.compact
    end

    def clear
      @key = @value = nil
      @children = []
    end

    def empty?
      self.size == 0
    end

    def each(&block)
      yield(@value) if @value
      children.each {|child| child.each(&block) }
    end

    def size
      children.inject(@value ? 1 : 0) {|sum, child| sum + child.size }
    end

    def find(key)
      if @key
        if @key.index(key) == 0
          self
        elsif key.index(@key) == 0
          child = @children[index(key)]
          child ? child.find(key) : Trie.new
        else
          Trie.new
        end
      else
        self
      end
    end

    def insert(key, value)
      if !@key
        @key = key
        @value = value
      elsif @key == key
        @value = value
      elsif @key.index(key) == 0
        child = Trie.new(@key, @value, @children)
        @children = []
        @children[@key[key.length].ord] = child
        @key = key
        @value = value
      elsif key.index(@key) == 0
        i = index(key)
        if @children[i]
          @children[i].insert(key, value)
        else
          @children[i] = Trie.new(key, value)
        end
      else
        n = 0
        n += 1 while key[n] == @key[n]

        child1 = Trie.new(@key, @value, @children)
        child2 = Trie.new(key, value)

        @value = nil
        @key = @key[0...n]
        @children = []
        @children[index(child1.key)] = child1
        @children[index(child2.key)] = child2
      end
    end

    def inspect
      "#<Gitrb::Trie @key=#{@key.inspect}, @value=#{@value.inspect}, @children=#{@children.compact.inspect}>"
    end

    private

    def index(key)
      key[@key.length].ord
    end
  end
end
