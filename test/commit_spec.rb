require "#{File.dirname(__FILE__)}/../lib/gitrb"
require 'pp'

describe Gitrb::Commit do

  REPO = '/tmp/gitrb_test'

  attr_reader :repo

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO

    @repo = Gitrb::Repository.new(:path => REPO, :create => true)
  end

  it "should dump in right format" do
    user = Gitrb::User.new("hanni", "hanni@email.de", Time.now)

    commit = Gitrb::Commit.new
    commit.tree = @repo.root
    commit.author = user
    commit.committer = user
    commit.message = "This is a message"

    content = commit.dump

    content.should == "tree #{@repo.root.id}
author #{user.dump}
committer #{user.dump}

This is a message"
  end

  it "should be readable by git binary" do
    time = Time.local(2009, 4, 20)
    author = Gitrb::User.new("hans", "hans@email.de", time)

    repo.root['a'] = Gitrb::Blob.new(:data => "Yay")
    commit = repo.commit("Commit Message", author, author)

    IO.popen("git log") do |io|
      io.gets.should == "commit #{commit.id}\n"
      io.gets.should == "Author: hans <hans@email.de>\n"
      io.gets.should == "Date:   Mon Apr 20 00:00:00 2009 #{Time.now.strftime('%z')}\n"
      io.gets.should == "\n"
      io.gets.should == "    Commit Message\n"
    end
  end

  it "should diff 2 commits" do
    repo.root['x'] = Gitrb::Blob.new(:data => 'a')
    repo.root['y'] = Gitrb::Blob.new(:data => "
First Line.
Second Line.
Last Line.
")
    a = repo.commit

    repo.root.delete('x')
    repo.root['y'] = Gitrb::Blob.new(:data => "
First Line.
Last Line.
Another Line.
")
    repo.root['z'] = Gitrb::Blob.new(:data => 'c')

    b = repo.commit

    diff = repo.diff(a, b)
  end

end
