module Gitrb
  class Reference
    undef_method :id, :type rescue nil

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
        return (mode & 0x4000 == 0x4000) ? :tree : :blob
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
