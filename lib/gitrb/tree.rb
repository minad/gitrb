class StringIO
  if RUBY_VERSION > '1.9'
    def read_bytes_until(char)
      str = ''
      while ((ch = getc) != char) && !eof
        str << ch
      end
      str
    end
  else
    def read_bytes_until(char)
      str = ''
      while ((ch = getc.chr) != char) && !eof
        str << ch
      end
      str
    end
  end
end

module Gitrb

  class Tree < Gitrb::Object
    include Enumerable

    attr_accessor :mode, :repository

    # Initialize a tree
    def initialize(options = {})
      super(options)
      @children = {}
      @mode = options[:mode] || "040000"
      parse(options[:data]) if options[:data]
      @modified = true if !id
    end

    def type
      'tree'
    end

    def ==(other)
      Tree === other && id == other.id
    end

    # Set new repository (modified flag is reset)
    def id=(id)
      super
      @modified = false
    end

    # Has this tree been modified?
    def modified?
      @modified || @children.values.any? { |entry| entry.type == 'tree' && entry.modified? }
    end

    def dump
      @children.to_a.sort {|a,b| a.first <=> b.first }.map do |name, child|
	child.save if !(Reference === child) || child.resolved?
        "#{child.mode} #{name}\0#{[child.id].pack("H*")}"
      end.join
    end

    # Save this treetree back to the git repository.
    #
    # Returns the object id of the tree.
    def save
      repository.put(self) if modified?
      id
    end

    # Read entry with specified name.
    def get(name)
      @children[name]
    end

    # Write entry with specified name.
    def put(name, value)
      raise RuntimeError, "no blob or tree" if !(Blob === value || Tree === value)
      value.repository = repository
      @modified = true
      @children[name] = value
      value
    end

    # Remove entry with specified name.
    def remove(name)
      @modified = true
      @children.delete(name.to_s)
    end

    # Does this key exist in the children?
    def has_key?(name)
      @children.has_key?(name.to_s)
    end

    def normalize_path(path)
      (path[0, 1] == '/' ? path[1..-1] : path).split('/')
    end

    # Read a value on specified path.
    def [](path)
      return self if path.empty?
      normalize_path(path).inject(self) do |tree, key|
        raise RuntimeError, 'Not a tree' if tree.type != 'tree'
        tree.get(key) or return nil
      end
    end

    # Write a value on specified path.
    def []=(path, value)
      list = normalize_path(path)
      tree = list[0..-2].to_a.inject(self) do |tree, name|
        raise RuntimeError, 'Not a tree' if tree.type != 'tree'
        tree.get(name) || tree.put(name, Tree.new(:repository => repository))
      end
      tree.put(list.last, value)
    end

    # Delete a value on specified path.
    def delete(path)
      list = normalize_path(path)

      tree = list[0..-2].to_a.inject(self) do |tree, key|
        tree.get(key) or return
      end

      tree.remove(list.last)
    end

    # Iterate over all children
    def each(&block)
      @children.sort.each do |name, child|
        yield(name, child)
      end
    end

    def names
      @children.keys.sort
    end

    def values
      map { |name, child| child }
    end

    alias children values

    private

    # Read the contents of a raw git object.
    def parse(data)
      @children.clear
      data = StringIO.new(data)
      while !data.eof?
        mode = data.read_bytes_until(' ')
        name = data.read_bytes_until("\0")
        id   = data.read(20).unpack("H*").first
        @children[name] = Reference.new(:repository => repository, :id => id, :mode => mode)
      end
    end

  end

end
