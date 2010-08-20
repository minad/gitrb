module Gitrb

  class Commit < GitObject
    attr_accessor :tree, :parents, :author, :committer, :message

    def initialize(options = {})
      super(options)
      @parents = [options[:parents]].flatten.compact
      @tree = options[:tree]
      @author = options[:author]
      @committer = options[:committer]
      @message = options[:message]
      parse(options[:data]) if options[:data]
    end

    def type
      :commit
    end

    def date
      (committer && committer.date) || (author && author.date)
    end

    def save
      repository.put(self)
      id
    end

    def dump
      [ "tree #{tree.id}",
        @parents.map { |p| "parent #{p.id}" },
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
      repository.set_encoding(@message)

      headers.split("\n").each do |header|
        key, value = header.split(' ', 2)

        case key
        when 'parent'
          @parents << Reference.new(:repository => repository, :id => repository.set_encoding(value))
        when 'author'
          @author = User.parse(repository.set_encoding(value))
        when 'committer'
          @committer = User.parse(repository.set_encoding(value))
        when 'tree'
          @tree = Reference.new(:repository => repository, :id => repository.set_encoding(value))
        end
      end

      self
    end

  end

end
