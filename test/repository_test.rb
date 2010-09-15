require 'helper'

describe Gitrb do
  before do
    FileUtils.rm_rf REPO_PATH
    Dir.mkdir REPO_PATH
    @repo = Gitrb::Repository.new(:path => REPO_PATH, :create => true)
  end

  it 'should put and get objects by sha' do
    blob1 = repo.put(Gitrb::Blob.new(:data => 'Hello'))
    blob2 = repo.put(Gitrb::Blob.new(:data => 'World'))

    repo.get(blob1.id).should.be.identical_to blob1
    repo.get(blob1.id[0..4]).should.be.identical_to blob1
    repo.get(blob1.id[0..10]).should.be.identical_to blob1

    repo.get(blob2.id).should.be.identical_to blob2
    repo.get(blob2.id[0..4]).should.be.identical_to blob2
    repo.get(blob2.id[0..10]).should.be.identical_to blob2
  end

  it 'should find commits by revision' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    commit1 = repo.commit

    repo.get('HEAD').should.be.identical_to commit1
    repo.get('master').should.be.identical_to commit1
    lambda { repo.get('HEAD^') }.should.raise(Gitrb::NotFound)

    repo.root['a'] = Gitrb::Blob.new(:data => 'World')
    commit2 = repo.commit

    repo.get('master').should.be.identical_to commit2
    repo.get('HEAD').should.be.identical_to commit2
    repo.get('HEAD^').should.be.identical_to commit1
    repo.get('HEAD~').should.be.identical_to commit1
    lambda { repo.get('HEAD^^') }.should.raise(Gitrb::NotFound)
  end

  it 'should find modified entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')

    repo.root.should.be.modified

    repo.commit

    repo.root.should.not.be.modified

    repo.root['a'] = Gitrb::Blob.new(:data => 'Bello')

    repo.root.should.be.modified
  end

  it 'should load a repo' do
    file 'a', 'Hello'
    file 'b', 'World'

    repo.refresh

    repo.root['a'].data.should.equal 'Hello'
    repo.root['b'].data.should.equal 'World'
  end

  it 'should load folders' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'

    repo.refresh

    repo.root['x'].git_object.should.be.kind_of(Gitrb::Tree)
    repo.root['y'].git_object.should.be.kind_of(Gitrb::Tree)

    repo.root['x']['a'].data.should.equal 'Hello'
    repo.root['y']['b'].data.should.equal 'World'
  end

  it 'should detect modification' do
    repo.transaction do
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'a')
    end

    repo.refresh

    repo.root['x/a'].data.should.equal 'a'

    repo.transaction do
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'b')
      repo.root['x'].should.be.modified
      repo.root.should.be.modified
    end

    repo.refresh

    repo.root['x/a'].data.should.equal 'b'
  end

  it 'should resolve paths' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'

    repo.refresh

    repo.root['x/a'].data.should.equal 'Hello'
    repo.root['y/b'].data.should.equal 'World'

    repo.root['y/b'] = Gitrb::Blob.new(:data => 'Now this')

    repo.root['y']['b'].data.should.equal 'Now this'
  end

  it 'should create new trees' do
    repo.root['new/tree'] = Gitrb::Blob.new(:data => 'This tree')
    repo.root['new/tree'].data.should.equal 'This tree'
  end

  it 'should delete entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root.delete('a')

    repo.root['a'].should.be.nil
  end

  it 'should move entries' do
    repo.root['a/b/c'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root['a/b/c'].data.should.equal 'Hello'
    repo.root.move('a/b/c', 'x/y/z')
    repo.root['a/b/c'].should.be.nil
    repo.root['x/y/z'].data.should.equal 'Hello'
  end

  it 'should have a head commit' do
    file 'a', 'Hello'

    repo.refresh
    repo.head.should.not.be.nil
  end

  it 'should rollback a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    begin
      repo.transaction do
        repo.root['a/b'] = Gitrb::Blob.new(:data => 'Changed')
        repo.root['x/a'] = Gitrb::Blob.new(:data => 'Added')
        raise 'boo'
      end
    rescue RuntimeError => ex
      ex.message.should.equal 'boo'
    end

    repo.root['a/b'].data.should.equal 'Hello'
    repo.root['c/d'].data.should.equal 'World'
    repo.root['x/a'].should.be.nil
  end

  it 'should commit a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    repo.transaction do
      repo.root['a/b'] = Gitrb::Blob.new(:data => 'Changed')
      repo.root['x/a'] = Gitrb::Blob.new(:data => 'Added')
    end

    a = ls_tree(repo.root['a'].id)
    x = ls_tree(repo.root['x'].id)

    a.should.equal [["100644", "blob", "b653cf27cef08de46da49a11fa5016421e9e3b32", "b"]]
    x.should.equal [["100644", "blob", "87d2b203800386b1cc8735a7d540a33e246357fa", "a"]]

    repo.git_show(a[0][2]).should.equal 'Changed'
    repo.git_show(x[0][2]).should.equal 'Added'
  end

  it "should save blobs" do
    repo.root['a'] = Gitrb::Blob.new(:data => 'a')
    repo.root['b'] = Gitrb::Blob.new(:data => 'b')
    repo.root['c'] = Gitrb::Blob.new(:data => 'c')

    repo.commit

    a = repo.root['a'].id
    b = repo.root['b'].id
    c = repo.root['c'].id

    repo.git_show(a).should.equal 'a'
    repo.git_show(b).should.equal 'b'
    repo.git_show(c).should.equal 'c'
  end

  it 'should find all objects' do
    repo.root['c'] = Gitrb::Blob.new(:data => 'Hello')
    repo.root['d'] = Gitrb::Blob.new(:data => 'World')
    repo.commit

    repo.root.to_a[0][1].data.should.equal 'Hello'
    repo.root.to_a[1][1].data.should.equal 'World'
  end

  it "should load log" do
    repo.log.should.be.empty

    repo.root['a'] = Gitrb::Blob.new(:data => 'a')
    repo.commit 'added a'

    repo.root['b'] = Gitrb::Blob.new(:data => 'b')
    repo.commit 'added b'

    repo.log[0].message.should.equal 'added b'
    repo.log[1].message.should.equal 'added a'
  end

  it "should load tags" do
    file 'a', 'init'

    repo.git_tag('-m', 'message', '0.1')

    repo.refresh

    user = repo.default_user
    id = File.read(repo.path + '/refs/tags/0.1')
    tag = repo.get(id)

    tag.tagtype.should.equal 'commit'
    tag.object.git_object.should.equal repo.head
    tag.tagger.name.should.equal user.name
    tag.tagger.email.should.equal user.email
    tag.message.should =~ /message/
  end

  it 'should detect changes and refresh' do
    file 'a', 'data'
    repo.root['a'].should.be.nil
    repo.should.be.changed
    repo.refresh
    repo.should.not.be.changed
    repo.root['a'].data.should.equal 'data'
  end

  it 'should clear cache' do
    file 'a', 'data'
    repo.refresh
    repo.root['a'].data.should.equal 'data'
    repo.clear
    repo.root['a'].data.should.equal 'data'
  end

  it "should diff 2 commits" do
    repo.root['x'] = Gitrb::Blob.new(:data => 'a')
    repo.root['y'] = Gitrb::Blob.new(:data => "\nFirst Line.\nSecond Line.\nLast Line.\n")
    a = repo.commit

    repo.diff(:to => a).patch.should.include "+First Line.\n+Second Line.\n+Last Line."
    repo.root['y'] = Gitrb::Blob.new(:data => "\nFirst Line.\nLast Line.\nAnother Line.\n")
    b = repo.commit

    repo.diff(:from => a, :to => b).patch.should.include '+Another Line.'
    repo.diff(:from => a, :to => b).patch.should.include '-Second Line.'
  end

end
