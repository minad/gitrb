require 'zlib'
require 'digest/sha1'
require 'yaml'
require 'fileutils'
require 'logger'
require 'enumerator'

require 'gitrb/util'
require 'gitrb/repository'
require 'gitrb/object'
require 'gitrb/blob'
require 'gitrb/diff'
require 'gitrb/tree'
require 'gitrb/tag'
require 'gitrb/user'
require 'gitrb/pack'
require 'gitrb/commit'
require 'gitrb/trie'

module Gitrb
  class NotFound < StandardError; end

  class Repository
    attr_reader :path, :index, :root, :branch, :lock_file, :head, :encoding

    SHA_PATTERN = /[A-Fa-f0-9]{5,40}/
    REVISION_PATTERN = /[\w\-\.]+([\^~](\d+)?)*/

    # Encoding stuff
    DEFAULT_ENCODING = 'utf-8'

    if RUBY_VERSION > '1.9'
      def set_encoding(s); s.force_encoding(@encoding); end
    else
      def set_encoding(s); s; end
    end

    # Initialize a repository.
    def initialize(options = {})
      @bare    = options[:bare] || false
      @branch  = options[:branch] || 'master'
      @logger  = options[:logger] || Logger.new(nil)
      @encoding = options[:encoding] || DEFAULT_ENCODING

      @path = options[:path]
      @path.chomp!('/')
      @path += '/.git' if !@bare

      if options[:create] && !File.exists?("#{@path}/objects")
        FileUtils.mkpath(@path) if !File.exists?(@path)
        raise ArgumentError, "Not a valid Git repository: '#{@path}'" if !File.directory?(@path)
        if @bare
          Dir.chdir(@path) { git_init('--bare') }
        else
          Dir.chdir(@path[0..-6]) { git_init }
        end
      else
        raise ArgumentError, "Not a valid Git repository: '#{@path}'" if !File.directory?("#{@path}/objects")
      end

      load_packs
      load
    end

    # Bare repository?
    def bare?
      @bare
    end

    # Switch branch
    def branch=(branch)
      @branch = branch
      load
    end

    # Has our repository been changed on disk?
    def changed?
      head.nil? or head.id != read_head_id
    end

    # Load the repository, if it has been changed on disk.
    def refresh
      load if changed?
    end

    # Is there any transaction going on?
    def in_transaction?
      Thread.current['gitrb_repository_lock']
    end

    # Diff
    def diff(from, to, path = nil)
      if from && !(Commit === from)
        raise ArgumentError if !(String === from)
        from = Reference.new(:repository => self, :id => from)
      end
      if !(Commit === to)
        raise ArgumentError if !(String === to)
        to = Reference.new(:repository => self, :id => to)
      end
      Diff.new(from, to, git_diff_tree('--root', '-u', '--full-index', from && from.id, to.id, '--', path))
    end

    # All changes made inside a transaction are atomic. If some
    # exception occurs the transaction will be rolled back.
    #
    # Example:
    #   repository.transaction { repository['a'] = 'b' }
    #
    def transaction(message = '', author = nil, committer = nil)
      start_transaction
      result = yield
      commit(message, author, committer)
      result
    rescue
      rollback_transaction
      raise
    ensure
      finish_transaction
    end

    # Write a commit object to disk and set the head of the current branch.
    #
    # Returns the commit object
    def commit(message = '', author = nil, committer = nil)
      return if !root.modified?

      author ||= default_user
      committer ||= author
      root.save

      commit = Commit.new(:repository => self,
                          :tree => root,
                          :parent => head,
                          :author => author,
                          :committer => committer,
                          :message => message)
      commit.save

      write_head_id(commit.id)
      load

      commit
    end

    # Returns a list of commits starting from head commit.
    def log(limit = 10, start = nil, path = nil)
      ### FIX: tformat need --pretty option
      args = ['--pretty=tformat:%H%n%P%n%T%n%an%n%ae%n%at%n%cn%n%ce%n%ct%n%x00%s%n%b%x00', "-#{limit}", ]
      args << start if start
      args << "--" << path if path && !path.empty?
      log = git_log(*args).split(/\n*\x00\n*/)
      commits = []
      log.each_slice(2) do |data, message|
        data = data.split("\n")
        commits << Commit.new(:repository => self,
                              :id => data[0],
                              :parent => data[1].empty? ? nil : Reference.new(:repository => self, :id => data[1]),
                              :tree => Reference.new(:repository => self, :id => data[2]),
                              :author => User.new(data[3], data[4], Time.at(data[5].to_i)),
                              :committer => User.new(data[6], data[7], Time.at(data[8].to_i)),
                              :message => message.strip)
      end
      commits
    rescue => ex
      return [] if ex.message =~ /bad default revision 'HEAD'/i
      raise
    end

    # Get an object by its id.
    #
    # Returns a tree, blob, commit or tag object.
    def get(id)
      raise NotFound, "No id given" if id.nil?
      if id =~ SHA_PATTERN
        raise NotFound, "Sha too short" if id.length < 5
        list = @objects.find(id).to_a
        return list.first if list.size == 1
      elsif id =~ REVISION_PATTERN
        list = git_rev_parse(id).split("\n") rescue nil
        raise NotFound, "Revision not found" if !list || list.empty?
        raise NotFound, "Revision is ambiguous" if list.size > 1
        id = list.first
      end

      @logger.debug "gitrb: Loading #{id}"

      path = object_path(id)
      if File.exists?(path) || (glob = Dir.glob(path + '*')).size >= 1
        if glob
          raise NotFound, "Sha is ambiguous" if glob.size > 1
          path = glob.first
          id = path[-41..-40] + path[-38..-1]
        end

        buf = File.open(path, 'rb') { |f| f.read }

        raise NotFound, "Not a loose object: #{id}" if !legacy_loose_object?(buf)

        header, content = Zlib::Inflate.inflate(buf).split("\0", 2)
        type, size = header.split(' ', 2)

        raise NotFound, "Bad object: #{id}" if content.length != size.to_i
      else
        trie = @packs.find(id)
	raise NotFound, "Object not found" if !trie

        id += trie.key[-(41 - id.length)...-1]

        list = trie.to_a
	raise NotFound, "Sha is ambiguous" if list.size > 1

        pack, offset = list.first
        content, type = pack.get_object(offset)
      end

      @logger.debug "gitrb: Loaded #{id}"

      set_encoding(id)
      object = Gitrb::Object.factory(type, :repository => self, :id => id, :data => content)
      @objects.insert(id, object)
      object
    end

    def get_tree(id)   get_type(id, 'tree') end
    def get_blob(id)   get_type(id, 'blob') end
    def get_commit(id) get_type(id, 'commit') end

    # Write a raw object to the repository.
    #
    # Returns the object.
    def put(object)
      content = object.dump
      data = "#{object.type} #{content.bytesize rescue content.length}\0#{content}"
      id = sha(data)
      path = object_path(id)

      @logger.debug "gitrb: Storing #{id}"

      if !File.exists?(path)
        FileUtils.mkpath(File.dirname(path))
        File.open(path, 'wb') do |f|
          f.write Zlib::Deflate.deflate(data)
        end
      end

      @logger.debug "gitrb: Stored #{id}"

      set_encoding(id)
      object.repository = self
      object.id = id
      @objects.insert(id, object)

      object
    end

    def method_missing(name, *args, &block)
      cmd = name.to_s
      if cmd[0..3] == 'git_'
        ENV['GIT_DIR'] = path
        args = args.flatten.compact.map {|s| "'" + s.to_s.gsub("'", "'\\\\''") + "'" }.join(' ')
        cmd = cmd[4..-1].tr('_', '-')
        cmd = "git #{cmd} #{args} 2>&1"

        @logger.debug "gitrb: #{cmd}"

	# Read in binary mode (ascii-8bit) and convert afterwards
        out = if block_given?
		IO.popen(cmd, 'rb', &block)
	      else
                set_encoding IO.popen(cmd, 'rb') {|io| io.read }
              end

        if $?.exitstatus > 0
          return '' if $?.exitstatus == 1 && out == ''
          raise RuntimeError, "#{cmd}: #{out}"
        end

        out
      else
        super
      end
    end

    def default_user
      name = git_config('user.name').chomp
      email = git_config('user.email').chomp
      if name.empty?
        require 'etc'
        user = Etc.getpwnam(Etc.getlogin)
        name = user.gecos
      end
      if email.empty?
        require 'etc'
        email = Etc.getlogin + '@' + `hostname -f`.chomp
      end
      User.new(name, email)
    end

    def dup
      super.instance_eval do
        @objects = Trie.new
        load
        self
      end
    end

    protected

    # Start a transaction.
    #
    # Tries to get lock on lock file, load the this repository if
    # has changed in the repository.
    def start_transaction
      file = File.open("#{head_path}.lock", "w")
      file.flock(File::LOCK_EX)
      Thread.current['gitrb_repository_lock'] = file
      refresh
    end

    # Rerepository the state of the repository.
    #
    # Any changes made to the repository are discarded.
    def rollback_transaction
      @objects.clear
      load
      finish_transaction
    end

    # Finish the transaction.
    #
    # Release the lock file.
    def finish_transaction
      Thread.current['gitrb_repository_lock'].close rescue nil
      Thread.current['gitrb_repository_lock'] = nil
      File.unlink("#{head_path}.lock") rescue nil
    end

    def get_type(id, expected)
      object = get(id)
      raise NotFound, "Wrong type #{object.type}, expected #{expected}" if object && object.type != expected
      object
    end

    def load_packs
      @packs   = Trie.new
      @objects = Trie.new

      packs_path = "#{@path}/objects/pack"
      if File.directory?(packs_path)
        Dir.open(packs_path) do |dir|
          entries = dir.select { |entry| entry =~ /\.pack$/i }
          entries.each do |entry|
            @logger.debug "gitrb: Loading pack #{entry}"
            pack = Pack.new(File.join(packs_path, entry))
            pack.each_object {|id, offset| @packs.insert(id, [pack, offset]) }
          end
        end
      end
    end

    def load
      if id = read_head_id
        @head = get_commit(id)
        @root = @head.tree
      else
        @head = nil
        @root = Tree.new(:repository => self)
      end
      @logger.debug "gitrb: Reloaded, head is #{@head ? head.id : 'nil'}"
    end

    # Returns the hash value of an object string.
    def sha(str)
      Digest::SHA1.hexdigest(str)[0, 40]
    end

    # Returns the path to the current head file.
    def head_path
      "#{path}/refs/heads/#{branch}"
    end

    # Returns the path to the object file for given id.
    def object_path(id)
      "#{path}/objects/#{id[0...2]}/#{id[2..39]}"
    end

    # Read the id of the head commit.
    #
    # Returns the object id of the last commit.
    def read_head_id
      if File.exists?(head_path)
        File.read(head_path).strip
      elsif File.exists?("#{path}/packed-refs")
        File.open("#{path}/packed-refs", "rb") do |io|
          while line = io.gets
            line.strip!
            next if line[0..0] == '#'
            line = line.split(' ')
            return line[0] if line[1] == "refs/heads/#{branch}"
          end
        end
      end
    end

    def write_head_id(id)
      File.open(head_path, "wb") {|file| file.write(id) }
    end

    def legacy_loose_object?(buf)
      buf[0].ord == 0x78 && ((buf[0].ord << 8) | buf[1].ord) % 31 == 0
    end

  end
end
