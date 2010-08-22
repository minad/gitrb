module Gitrb

  # This class stores the raw string data of a blob
  class Blob < GitObject

    attr_reader :data, :mode

    # Initialize a Blob
    def initialize(options = {})
      super(options)
      @data = options[:data]
      @mode = options[:mode] || 0100644
      @modified = true if !id
    end

    def modified?
      @modified
    end

    # Set mode
    def mode=(mode)
      if mode != @mode
        @mode = mode
        @modified = true
      end
    end

    # Set data
    def data=(data)
      if data != @data
        @data = data
        @modified = true
      end
    end

    # Set new repository (modified flag is reset)
    def id=(id)
      @modified = false
      super
    end

    def type
      :blob
    end

    def dump
      @data
    end

    # Save the data to the git object repository
    def save
      raise 'Blob is empty' if !data
      repository.put(self) if modified?
      id
    end

  end

end
