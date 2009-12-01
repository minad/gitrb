require "#{File.dirname(__FILE__)}/../lib/gitrb"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe Gitrb do

  REPO = '/tmp/gitrb_test.git'

  attr_reader :repo

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO

    @repo = Gitrb::Repository.new(:path => REPO, :create => true)
  end

  it 'should fail to initialize without a valid git repository' do
    lambda {
      Gitrb::Repository.new('/foo', 'master', true)
    }.should raise_error(ArgumentError)
  end

  it 'should save and load entries' do
    repo.root['a'] = Gitrb::Blob.new(:data => 'Hello')
    repo.commit

    repo.root['a'].data.should == 'Hello'
  end
end
