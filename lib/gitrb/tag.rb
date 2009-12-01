module Gitrb

  class Tag < Gitrb::Object
    attr_accessor :object, :tagtype, :tagger, :message

    def initialize(options = {})
      super(options)
      parse(options[:data]) if options[:data]
    end

    def ==(other)
      Tag === other and id == other.id
    end

    def parse(data)
      headers, @message = data.split("\n\n", 2)

      headers.split("\n").each do |header|
        key, value = header.split(' ', 2)
        case key
        when 'type'
          @tagtype = value
        when 'object'
          @object = Reference.new(:repository => repository, :id => value)
        when 'tagger'
          @tagger = User.parse(value)
        end
      end

      self
    end

  end

end
