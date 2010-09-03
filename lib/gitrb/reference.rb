module Gitrb
  class Reference
    undef_method :id, :type rescue nil

    def initialize(properties = {})
      @properties = properties
      @object = nil
    end

    def method_missing(name, *args, &block)
      if @object
        if @object.respond_to? name
          instance_eval %{def self.#{name}(*args, &block); @object.send("#{name}", *args, &block); end}
        end
        @object.send(name, *args, &block)
      elsif name == :type && (mode = @properties['mode'] || @properties[:mode])
        (mode & 040000 == 040000) ? :tree : :blob
      elsif @properties.include?(name)
        @properties[name]
      elsif @properties.include?(name.to_s)
        @properties[name.to_s]
      else
        @object = repository.get(id)
        method_missing(name, *args, &block)
      end
    end

    def resolved?
      @object != nil
    end
  end
end
