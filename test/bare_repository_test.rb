require 'helper'

describe Gitrb do

  REPO = '/tmp/gitrb_test.git'

  before do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO

    @repo = Gitrb::Repository.new(:path => REPO, :create => true, :bare => true)
  end

  it 'should fail to initialize without a valid git repository' do
    lambda {
      Gitrb::Repository.new('/foo', 'master', true)
    }.should.raise(ArgumentError)
  end

  it 'should save and load entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    repo.commit

    repo.root['a'].data.should.equal 'Hello'
  end
end
