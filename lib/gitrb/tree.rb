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
      @modified = false
      super
    end

    # Has this tree been modified?
    def modified?
      @modified || @children.values.any? { |entry| entry.type == 'tree' && entry.modified? }
    end

    def dump
      @children.to_a.sort {|a,b| a.first <=> b.first }.map do |name, child|
	child.save if !(Reference === child) || child.resolved?
        "#{child.mode} #{name}\0#{repository.set_encoding [child.id].pack("H*")}"
      end.join
    end

    # Save this treetree back to the git repository.
    #
    # Returns the object id of the tree.
    def save
      repository.put(self) if modified?
      id
    end

    # Does this key exist in the children?
    def exists?(name)
      self[name] != nil
    end

    # Read an entry on specified path.
    def [](path)
      path = normalize_path(path)
      return self if path.empty?
      entry = @children[path.first]
      if path.size == 1
        entry
      elsif entry
        raise RuntimeError, 'Not a tree' if entry.type != 'tree'
        entry[path[1..-1]]
      end
    end

    # Write an entry on specified path.
    def []=(path, entry)
      path = normalize_path(path)
      if path.empty?
        raise RuntimeError, 'Empty path'
      elsif path.size == 1
        raise RuntimeError, 'No blob or tree' if entry.type != 'tree' && entry.type != 'blob'
        entry.repository = repository
        @modified = true
        @children[path.first] = entry
      else
        tree = @children[path.first]
        if !tree
          tree = @children[path.first] = Tree.new(:repository => repository)
          @modified = true
        end
        raise RuntimeError, 'Not a tree' if tree.type != 'tree'
        tree[path[1..-1]] = entry
      end
    end

    # Delete a entry on specified path.
    def delete(path)
      path = normalize_path(path)
      if path.empty?
        raise RuntimeError, 'Empty path'
      elsif path.size == 1
        @modified = true
        @children.delete(path.first)
      else
        tree = @children[path.first]
        raise RuntimeError, 'Not a tree' if tree.type != 'tree'
        tree.delete(path[1..-1])
      end
    end

    # Move a entry
    def move(path, dest)
      self[dest] = delete(path)
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

    def normalize_path(path)
      return path if Array === path
      path = path.to_s
      (path[0, 1] == '/' ? path[1..-1] : path).split('/')
    end

    # Read the contents of a raw git object.
    def parse(data)
      @children.clear
      data = StringIO.new(data)
      while !data.eof?
        mode = repository.set_encoding Util.read_bytes_until(data, ' ')
        name = repository.set_encoding Util.read_bytes_until(data, "\0")
        id   = repository.set_encoding data.read(20).unpack("H*").first
        @children[name] = Reference.new(:repository => repository, :id => id, :mode => mode)
      end
    end

  end

end
