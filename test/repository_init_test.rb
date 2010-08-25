require 'helper'

describe Gitrb do
  it 'should fail to initialize without a valid git repository' do
    File.exists?('/foo').should.be.false
    lambda do
      Gitrb::Repository.new(:path => '/foo', :branch => 'master', :bare => true)
    end.should.raise(ArgumentError)
    File.exists?('/foo').should.be.false
    lambda do
      Gitrb::Repository.new(:path => '/foo', :branch => 'master')
    end.should.raise(ArgumentError)
    File.exists?('/foo').should.be.false
  end

  it 'should create repository on relative path' do
    FileUtils.rm_rf('/tmp/gitrb_test')
    Dir.chdir('/tmp') do
      Gitrb::Repository.new(:path => "gitrb_test/repo",
                            :bare => true, :create => true)
    end
    File.directory?('/tmp/gitrb_test/repo').should.be.true
    File.directory?('/tmp/gitrb_test/repo/objects').should.be.true
    File.exists?('/tmp/gitrb_test/repo/.git').should.be.false

    FileUtils.rm_rf('/tmp/gitrb_test')
    Dir.chdir('/tmp') do
      Gitrb::Repository.new(:path => "gitrb_test/repo", :create => true)
    end
    File.directory?('/tmp/gitrb_test/repo').should.be.true
    File.directory?('/tmp/gitrb_test/repo/.git').should.be.true
    File.directory?('/tmp/gitrb_test/repo/.git/objects').should.be.true
  end
end
