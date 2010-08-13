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
      repo.git_commit('-m', 'added #{file}')
      File.unlink(file)
    end
  end
end

class Bacon::Context
  include TestHelper
  attr_reader :repo
end
