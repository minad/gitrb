module Gitrb

  # This class stores the raw string data of a blob
  class Blob < GitObject

    attr_accessor :data, :mode

    # Initialize a Blob
    def initialize(options = {})
      super(options)
      @data = options[:data]
      @mode = options[:mode] || 0100644
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
      repository.put(self)
      id
    end

  end

end
