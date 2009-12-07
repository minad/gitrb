require "#{File.dirname(__FILE__)}/../lib/gitrb"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe Gitrb do

  include Helper

  REPO = '/tmp/gitrb_test'

  attr_reader :repo

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    @repo = Gitrb::Repository.new(:path => REPO, :create => true)
  end

  it 'should fail to initialize without a valid git repository' do
    lambda {
      Gitrb::Repository.new(:path => '/')
    }.should raise_error(ArgumentError)
  end

  it 'should find modified entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')

    repo.root.should be_modified

    repo.commit

    repo.root.should_not be_modified

    repo.root['a'] = Gitrb::Blob.new(:data => 'Bello')

    repo.root.should be_modified
  end

  it 'should load a repo' do
    file 'a', 'Hello'
    file 'b', 'World'

    repo.refresh

    repo.root['a'].data.should == 'Hello'
    repo.root['b'].data.should == 'World'
  end

  it 'should load folders' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'

    repo.refresh

    repo.root['x'].object.should be_kind_of(Gitrb::Tree)
    repo.root['y'].object.should be_kind_of(Gitrb::Tree)

    repo.root['x']['a'].data.should == 'Hello'
    repo.root['y']['b'].data.should == 'World'
  end

  it 'should detect modification' do
    repo.transaction do
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'a')
    end

    repo.refresh

    repo.root['x/a'].data.should == 'a'

    repo.transaction do
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'b')
      repo.root['x'].should be_modified
      repo.root.should be_modified
    end

    repo.refresh

    repo.root['x/a'].data.should == 'b'
  end

  it 'should resolve paths' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'

    repo.refresh

    repo.root['x/a'].data.should == 'Hello'
    repo.root['y/b'].data.should == 'World'

    repo.root['y/b'] = Gitrb::Blob.new(:data => 'Now this')

    repo.root['y']['b'].data.should == 'Now this'
  end

  it 'should create new trees' do
    repo.root['new/tree'] = Gitrb::Blob.new(:data => 'This tree')
    repo.root['new/tree'].data.should == 'This tree'
  end

  it 'should delete entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root.delete('a')

    repo.root['a'].should be_nil
  end

  it 'should move entries' do
    repo.root['a/b/c'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root['a/b/c'].data.should == 'Hello'
    repo.root.move('a/b/c', 'x/y/z')
    repo.root['a/b/c'].should be_nil
    repo.root['x/y/z'].data.should == 'Hello'
  end

  it 'should have a head commit' do
    file 'a', 'Hello'

    repo.refresh
    repo.head.should_not be_nil
  end

  it 'should detect changes' do
    file 'a', 'Hello'

    repo.should be_changed
  end

  it 'should rollback a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    begin
      repo.transaction do
        repo.root['a/b'] = 'Changed'
        repo.root['x/a'] = 'Added'
        raise
      end
    rescue
    end

    repo.root['a/b'].data.should == 'Hello'
    repo.root['c/d'].data.should == 'World'
    repo.root['x/a'].should be_nil
  end

  it 'should commit a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    repo.transaction do
      repo.root['a/b'] = Gitrb::Blob.new(:data => 'Changed')
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'Added')
    end

    a = ls_tree(repo.root['a'].object.id)
    x = ls_tree(repo.root['x'].object.id)

    a.should == [["100644", "blob", "b653cf27cef08de46da49a11fa5016421e9e3b32", "b"]]
    x.should == [["100644", "blob", "87d2b203800386b1cc8735a7d540a33e246357fa", "a"]]

    repo.git_show(a[0][2]).should == 'Changed'
    repo.git_show(x[0][2]).should == 'Added'
  end

  it "should save blobs" do
    repo.root['a'] = Gitrb::Blob.new(:data => 'a')
    repo.root['b'] = Gitrb::Blob.new(:data => 'b')
    repo.root['c'] = Gitrb::Blob.new(:data => 'c')

    repo.commit

    a = repo.root['a'].id
    b = repo.root['b'].id
    c = repo.root['c'].id

    repo.git_show(a).should == 'a'
    repo.git_show(b).should == 'b'
    repo.git_show(c).should == 'c'
  end

  it 'should allow only one transaction' do
    file 'a/b', 'Hello'

    ready = false

    repo.transaction do
      Thread.start do
        repo.transaction do
          repo.root['a/b'] = Gitrb::Blob.new(:data => 'Changed by second thread')
        end
        ready = true
      end
      repo.root['a/b'] = Gitrb::Blob.new(:data => 'Changed')
    end

    sleep 0.01 until ready

    repo.refresh

    repo.root['a/b'].data.should == 'Changed by second thread'
  end

  it 'should find all objects' do
    repo.refresh
    repo.root['c'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root['d'] = Gitrb::Blob.new(:data => 'World')
    repo.commit

    repo.root.to_a[0][1].data.should == 'Hello'
    repo.root.to_a[1][1].data.should == 'World'
  end

  it "should load log" do
    repo.root['a'] = Gitrb::Blob.new(:data => 'a')
    repo.commit 'added a'

    repo.root['b'] = Gitrb::Blob.new(:data => 'b')
    repo.commit 'added b'

    repo.log[0].message.should == 'added b'
    repo.log[1].message.should == 'added a'
  end

  it "should load tags" do
    file 'a', 'init'

    repo.git_tag('-m', 'message', '0.1')

    repo.refresh

    user = repo.default_user
    id = File.read(repo.path + '/refs/tags/0.1')
    tag = repo.get(id)

    tag.tagtype.should == 'commit'
    tag.object.object.should == repo.head
    tag.tagger.name.should == user.name
    tag.tagger.email.should == user.email
    tag.message.should =~ /message/
  end

end
