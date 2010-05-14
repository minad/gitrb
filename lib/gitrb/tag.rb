module Gitrb

  class Tag < GitObject
    attr_accessor :object, :tagtype, :tagger, :message

    def initialize(options = {})
      super(options)
      parse(options[:data]) if options[:data]
    end

    def ==(other)
      Tag === other && id == other.id
    end

    def parse(data)
      headers, @message = data.split("\n\n", 2)
      repository.set_encoding(@message)

      headers.split("\n").each do |header|
        key, value = header.split(' ', 2)
        case key
        when 'type'
          @tagtype = value
        when 'object'
          @object = Reference.new(:repository => repository, :id => repository.set_encoding(value))
        when 'tagger'
          @tagger = User.parse(repository.set_encoding(value))
        end
      end

      self
    end

  end

end
