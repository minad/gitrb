module Gitrb
  class GitObject
    attr_accessor :repository, :id

    def initialize(options = {})
      @repository = options[:repository]
      @id = options[:id]
    end

    def object
      self
    end

    def ==(other)
      self.class === other && id == other.id
    end

    @types = {}

    def self.inherited(subclass)
      @types[subclass.name[7..-1].downcase] = subclass
    end

    def self.factory(type, *args)
      klass = @types[type]
      raise NotImplementedError, "Object type not supported: #{type}" if !klass
      klass.new(*args)
    end
  end
end
