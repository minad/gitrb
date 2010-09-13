module Gitrb
  class NotFound < StandardError; end

  class CommandError < StandardError
    attr_reader :command, :args, :output

    def initialize(command, args, output)
      super("#{command} failed")
      @command = command
      @args = args
      @output = output
    end
  end

  Diff = Struct.new(:from, :to, :patch)

  class Repository
    attr_reader :path, :root, :branch, :head, :encoding

    def self.git_path
      @git_path ||= begin
        path = `which git`.chomp
        raise 'git not found' if $?.exitstatus != 0
        path
      end
    end

    SHA_PATTERN = /^[A-Fa-f0-9]{5,40}$/
    REVISION_PATTERN = /^[\w\-\.]+([\^~](\d+)?)*$/
    DEFAULT_ENCODING = 'utf-8'
    MIN_GIT_VERSION = '1.6.0'

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
      @lock = {}
      @transaction = Mutex.new

      @path = options[:path]
      @path.chomp!('/')
      @path += '/.git' if !@bare

      check_git_version if !options[:ignore_version]
      open_repository(options[:create])

      load_packs
      load
    end

    # Bare repository?
    def bare?
      @bare
    end

    # Switch branch
    def branch=(branch)
      @transaction.synchronize do
        @branch = branch
        load
      end
    end

    # Has our repository been changed on disk?
    def changed?
      !head || head.id != read_head_id
    end

    # Load the repository, if it has been changed on disk.
    def refresh
      load if changed?
    end

    # Clear cached objects
    def clear
      @transaction.synchronize do
        @objects.clear
        load
      end
    end

    # Is there any transaction going on?
    def in_transaction?
      !!@lock[Thread.current.object_id]
    end

    # Difference between versions
    # Options:
    #   :to             - Required target commit
    #   :from           - Optional source commit (otherwise comparision with empty tree)
    #   :path           - Restrict to path/or paths
    #   :detect_renames - Detect renames O(n^2)
    #   :detect_copies  - Detect copies O(n^2), very slow
    def diff(opts)
      from, to = opts[:from], opts[:to]
      if from && !(Commit === from)
        raise ArgumentError, "Invalid sha: #{from}" if from !~ SHA_PATTERN
        from = Reference.new(:repository => self, :id => from)
      end
      if !(Commit === to)
        raise ArgumentError, "Invalid sha: #{to}" if to !~ SHA_PATTERN
        to = Reference.new(:repository => self, :id => to)
      end
      Diff.new(from, to, git_diff_tree('--root', '--full-index', '-u',
                                       opts[:detect_renames] ? '-M' : nil,
                                       opts[:detect_copies] ? '-C' : nil,
                                       from ? from.id : nil, to.id, '--', *opts[:path]))
    end

    # All changes made inside a transaction are atomic. If some
    # exception occurs the transaction will be rolled back.
    #
    # Example:
    #   repository.transaction { repository['a'] = 'b' }
    #
    def transaction(message = '', author = nil, committer = nil)
      @transaction.synchronize do
        begin
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
      end
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
                          :parents => head,
                          :author => author,
                          :committer => committer,
                          :message => message)
      commit.save

      write_head_id(commit.id)
      load

      commit
    end

    # Returns a list of commits starting from head commit.
    # Options:
    #   :path      - Restrict to path/or paths
    #   :max_count - Maximum count of commits
    #   :skip      - Skip n commits
    #   :start     - Commit to start from
    def log(opts = {})
      max_count = opts[:max_count]
      skip = opts[:skip]
      start = opts[:start]
      raise ArgumentError, "Invalid commit: #{start}" if start.to_s =~ /^\-/
      log = git_log('--pretty=tformat:%H%n%P%n%T%n%an%n%ae%n%at%n%cn%n%ce%n%ct%n%x00%s%n%b%x00',
                    skip ? "--skip=#{skip.to_i}" : nil,
                    max_count ? "--max-count=#{max_count.to_i}" : nil, start, '--', *opts[:path]).split(/\n*\x00\n*/)
      commits = []
      log.each_slice(2) do |data, message|
        data = data.split("\n")
        parents = data[1].empty? ? nil : data[1].split(' ').map {|id| Reference.new(:repository => self, :id => id) }
        commits << Commit.new(:repository => self,
                              :id => data[0],
                              :parents => parents,
                              :tree => Reference.new(:repository => self, :id => data[2]),
                              :author => User.new(data[3], data[4], Time.at(data[5].to_i)),
                              :committer => User.new(data[6], data[7], Time.at(data[8].to_i)),
                              :message => message.strip)
      end
      commits
    rescue CommandError => ex
      return [] if ex.output =~ /bad default revision 'HEAD'/i
      raise
    end

    # Get an object by its id.
    #
    # Returns a tree, blob, commit or tag object.
    def get(id)
      raise ArgumentError, 'Invalid id given' if !(String === id)

      if id =~ SHA_PATTERN
        raise ArgumentError, "Sha too short: #{id}" if id.length < 5

        trie = @objects.find(id)
        raise NotFound, "Sha is ambiguous: #{id}" if trie.size > 1
        return trie.value if !trie.empty?
      elsif id =~ REVISION_PATTERN
        list = git_rev_parse(id).split("\n") rescue nil
        raise NotFound, "Revision not found: #{id}" if !list || list.empty?
        raise NotFound, "Revision is ambiguous: #{id}" if list.size > 1
        id = list.first

        trie = @objects.find(id)
        raise NotFound, "Sha is ambiguous: #{id}" if trie.size > 1
        return trie.value if !trie.empty?
      else
        raise ArgumentError, "Invalid id given: #{id}"
      end

      @logger.debug "gitrb: Loading #{id}"

      path = object_path(id)
      if File.exists?(path) || (glob = Dir.glob(path + '*')).size >= 1
        if glob
          raise NotFound, "Sha is ambiguous: #{id}" if glob.size > 1
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
	raise NotFound, "Object not found: #{id}" if trie.empty?
	raise NotFound, "Sha is ambiguous: #{id}" if trie.size > 1
        id = trie.key
        pack, offset = trie.value
        content, type = pack.get_object(offset)
      end

      @logger.debug "gitrb: Loaded #{type} #{id}"

      set_encoding(id)
      object = GitObject.factory(type, :repository => self, :id => id, :data => content)
      @objects.insert(id, object)
      object
    end

    def get_tree(id)   get_type(id, :tree) end
    def get_blob(id)   get_type(id, :blob) end
    def get_commit(id) get_type(id, :commit) end

    # Write a raw object to the repository.
    #
    # Returns the object.
    def put(object)
      raise ArgumentError unless object && GitObject === object

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

    def method_missing(name, *args)
      cmd = name.to_s
      if cmd[0..3] == 'git_'
        cmd = cmd[4..-1].tr('_', '-')
        args = args.flatten.compact.map {|a| a.to_s }

        @logger.debug "gitrb: #{self.class.git_path} #{cmd} #{args.inspect}"

        out = IO.popen('-', 'rb') do |io|
          if io
            # Read in binary mode (ascii-8bit) and convert afterwards
            block_given? ? yield(io) : set_encoding(io.read)
          else
            # child's stderr goes to stdout
            STDERR.reopen(STDOUT)
            ENV['GIT_DIR'] = path
            exec(self.class.git_path, cmd, *args)
          end
        end

        if $?.exitstatus > 0
          return '' if $?.exitstatus == 1 && out == ''
          raise CommandError.new("git #{cmd}", args, out)
        end

        out
      else
        super
      end
    end

    def default_user
      @default_user ||= begin
        name = git_config('user.name').chomp
        email = git_config('user.email').chomp
        name = ENV['USER'] if name.empty?
        email = ENV['USER'] + '@' + `hostname -f`.chomp if email.empty?
        User.new(name, email)
      end
    end

    private

    def check_git_version
      version = git_version
      raise "Invalid git version: #{version}" if version !~ /^git version ([\d\.]+)$/
      a = $1.split('.').map {|s| s.to_i }
      b = MIN_GIT_VERSION.split('.').map {|s| s.to_i }
      while !a.empty? && !b.empty? && a.first == b.first
        a.shift
        b.shift
      end
      raise "Minimum required git version is #{MIN_GIT_VERSION}" if a.first.to_i < b.first.to_i
    end

    def open_repository(create)
      if create && !File.exists?("#{@path}/objects")
        FileUtils.mkpath(@path) if !File.exists?(@path)
        raise ArgumentError, "Not a valid Git repository: '#{@path}'" if !File.directory?(@path)
        git_init(@bare ? '--bare' : nil)
      else
        raise ArgumentError, "Not a valid Git repository: '#{@path}'" if !File.directory?("#{@path}/objects")
      end
    end

    # Start a transaction.
    #
    # Tries to get lock on lock file, load the this repository if
    # has changed in the repository.
    def start_transaction
      file = File.open("#{head_path}.lock", 'w')
      file.flock(File::LOCK_EX)
      @lock[Thread.current.object_id] = file
      refresh
    end

    # Rerepository the state of the repository.
    #
    # Any changes made to the repository are discarded.
    def rollback_transaction
      @objects.clear
      load
    end

    # Finish the transaction.
    #
    # Release the lock file.
    def finish_transaction
      @lock[Thread.current.object_id].close rescue nil
      @lock.delete(Thread.current.object_id)
      File.unlink("#{head_path}.lock") rescue nil
    end

    def get_type(id, expected)
      object = get(id)
      raise NotFound, "Wrong type #{object.type}, expected #{expected}" if object && object.type != expected
      object
    end

    def load_packs
      @packs   = Trie.new
      @objects = Util::Synchronized.new(Trie.new)

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
      @logger.debug "gitrb: Reloaded, head is #{head ? head.id : 'nil'}"
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
        File.open("#{path}/packed-refs", 'rb') do |io|
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
      File.open(head_path, 'wb') {|file| file.write(id) }
    end

    def legacy_loose_object?(buf)
      buf[0].ord == 0x78 && ((buf[0].ord << 8) | buf[1].ord) % 31 == 0
    end
  end
end
