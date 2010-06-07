module Gitrb
  class Reference
    undef_method :id, :type rescue nil

    def initialize(properties = {})
      @properties = properties
      @object = nil
    end

    def method_missing(name, *args, &block)
      if @object
        unless name == :to_ary || name == :to_str
          # Ruby 1.9 uses the presence of the to_ary and to_str methods to determine if an object is coercable.
          # If we create these methods, Ruby will incorrectly think that the object can be converted to an array.
          instance_eval %{def self.#{name}(*args, &block); @object.send("#{name}", *args, &block); end}
        end
        @object.send(name, *args, &block)
      elsif name == :type && (mode = @properties['mode'] || @properties[:mode])
        (mode & 040000 == 040000) ? :tree : :blob
      elsif @properties.include?(name)
        @properties[name]
      elsif @properties.include?(name.to_s)
        @properties[name.to_s]
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
