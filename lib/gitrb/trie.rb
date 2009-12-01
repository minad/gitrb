module Gitrb
  class Trie
    include Enumerable

    attr_reader :key, :value

    def initialize(key = '', value = nil, children = [])
      @key = key
      @value = value
      @children = children
    end

    def clear
      @key = ''
      @value = nil
      @children.clear
    end

    def find(key)
      if key.empty?
        self
      else
        child = @children[key[0].ord]
        if child && key[0...child.key.length] == child.key
          child.find(key[child.key.length..-1])
        else
          nil
        end
      end
    end

    def insert(key, value)
      if key.empty?
        @value = value
        self
      else
        idx = key[0].ord
        child = @children[idx]
        if child
          child.split(key) if key[0...child.key.length] != child.key
          child.insert(key[child.key.length..-1], value)
        else
          @children[idx] = Trie.new(key, value)
        end
      end
    end

    def each(&block)
      yield(@value) if !@key.empty?
      @children.compact.each {|c| c.each(&block) }
    end

    def values
      to_a
    end

    def dup
      Trie.new(@key.dup, @value ? @value.dup : nil, @children.map {|c| c ? c.dup : nil })
    end

    def inspect
      "#<Gitrb::Trie @key=#{@key.inspect}, @value=#{@value.inspect}, @children=#{@children.compact.inspect}>"
    end

    def split(key)
      prefix = 0
      prefix += 1 while key[prefix] == @key[prefix]
      child = Trie.new(@key[prefix..-1], @value, @children)
      @children = []
      @children[@key[prefix].ord] = child
      @key = @key[0...prefix]
      @value = nil
    end
  end
end
