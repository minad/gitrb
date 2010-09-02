require 'helper'

describe Gitrb do
  before do
    FileUtils.rm_rf REPO_PATH
    Dir.mkdir REPO_PATH

    @repo = Gitrb::Repository.new(:path => REPO_PATH, :create => true, :bare => true)
  end

  it 'should save and load entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    repo.commit

    repo.root['a'].data.should.equal 'Hello'
  end
end
