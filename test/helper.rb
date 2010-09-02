require 'gitrb'

module TestHelper
  def ls_tree(id)
    repo.git_ls_tree(id).split("\n").map {|line| line.split(" ") }
  end

  def file(file, data)
    Dir.chdir(repo.path[0..-6]) do
      FileUtils.mkpath(File.dirname(file))
      open(file, 'w') { |io| io << data }

      repo.git_add(file)
      repo.git_commit('-m', "added #{file}")
      File.unlink(file)
    end
  end

  def with_git_dir
    old_path = ENV['GIT_DIR']
    ENV['GIT_DIR'] = repo.path
    yield
  ensure
    ENV['GIT_DIR'] = old_path
  end
end

class Bacon::Context
  include TestHelper
  attr_reader :repo
end

REPO_PATH = '/tmp/gitrb_test'
