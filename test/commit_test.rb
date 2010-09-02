require 'helper'

describe Gitrb::Commit do
  before do
    FileUtils.rm_rf REPO_PATH
    Dir.mkdir REPO_PATH

    @repo = Gitrb::Repository.new(:path => REPO_PATH, :create => true)
  end

  it "should dump in right format" do
    user = Gitrb::User.new("hanni", "hanni@email.de", Time.now)

    commit = Gitrb::Commit.new
    commit.tree = @repo.root
    commit.author = user
    commit.committer = user
    commit.message = "This is a message"

    content = commit.dump

    content.should.equal "tree #{@repo.root.id}
author #{user.dump}
committer #{user.dump}

This is a message"
  end

  it "should be readable by git binary" do
    time = Time.local(2009, 4, 20)
    author = Gitrb::User.new("hans", "hans@email.de", time)

    repo.root['a'] = Gitrb::Blob.new(:data => "Yay")
    commit = repo.commit("Commit Message", author, author)

    with_git_dir do
      IO.popen("git log") do |io|
        io.gets.should.equal "commit #{commit.id}\n"
        io.gets.should.equal "Author: hans <hans@email.de>\n"
        io.gets.should.equal "Date:   Mon Apr 20 00:00:00 2009 #{Time.now.strftime('%z')}\n"
        io.gets.should.equal "\n"
        io.gets.should.equal "    Commit Message\n"
      end
    end
  end

end
