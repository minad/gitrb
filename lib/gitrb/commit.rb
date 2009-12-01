module Gitrb

  class Commit < Gitrb::Object
    attr_accessor :tree, :parent, :author, :committer, :message

    def initialize(options = {})
      super(options)
      @parent = [options[:parent]].flatten.compact
      @tree = options[:tree]
      @author = options[:author]
      @committer = options[:committer]
      @message = options[:message]
      parse(options[:data]) if options[:data]
    end

    def type
      'commit'
    end

    def date
      (committer && committer.date) || (author && author.date)
    end

    def ==(other)
      Commit === other and id == other.id
    end

    def save
      repository.put(self)
      id
    end

    def dump
      [ "tree #{tree.id}",
        @parent.map { |p| "parent #{p.id}" },
        "author #{author.dump}",
        "committer #{committer.dump}",
        '',
        message ].flatten.join("\n")
    end

    def to_s
      id
    end

    private

    def parse(data)
      headers, @message = data.split("\n\n", 2)

      headers.split("\n").each do |header|
        key, value = header.split(' ', 2)

        case key
        when 'parent'
          @parent << Reference.new(:repository => repository, :id => value)
        when 'author'
          @author = User.parse(value)
        when 'committer'
          @committer = User.parse(value)
        when 'tree'
          @tree = Reference.new(:repository => repository, :id => value)
        end
      end

      self
    end

  end

end
