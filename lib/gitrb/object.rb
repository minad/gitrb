module Gitrb
  class Object
    attr_accessor :repository, :id
    alias sha id

    def initialize(options = {})
      @repository = options[:repository]
      @id = options[:id] || options[:sha]
    end

    CLASS = {}

    def object
      self
    end

    def self.inherited(subclass)
      CLASS[subclass.name[7..-1].downcase] = subclass
    end

    def self.factory(type, *args)
      klass = CLASS[type] or raise NotImplementedError, "Object type not supported: #{type}"
      klass.new(*args)
    end
  end

  class Reference
    def initialize(properties = {})
      @properties = properties
      @object = nil
    end

    def method_missing(name, *args, &block)
      if @object
        instance_eval %{def self.#{name}(*args, &block); @object.send("#{name}", *args, &block); end}
        @object.send(name, *args, &block)
      elsif name == :type && (mode = @properties['mode'] || @properties[:mode])
        mode = mode.to_i(8)
        return (mode & 0x4000 == 0x4000) ? 'tree' : 'blob'
      elsif @properties.include?(name)
        return @properties[name]
      elsif @properties.include?(name.to_s)
        return @properties[name.to_s]
      elsif object
        method_missing(name, *args, &block)
      else
        super
      end
    end

    def object
      @object ||= repository.get(id)
    end

    def resolved?
      @object != nil
    end
  end
end
