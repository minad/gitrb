require "#{File.dirname(__FILE__)}/../lib/gitrb"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe Gitrb::Tree do
  REPO = '/tmp/gitrb_test'

  include Helper

  attr_reader :repo, :tree

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO

    @repo = Gitrb::Repository.new(:path => REPO, :create => true)
  end

  it "should write a table" do
    tree = Gitrb::Tree.new(:repository => repo)

    tree['a'] = Gitrb::Blob.new(:data => 'a')
    tree['b'] = Gitrb::Blob.new(:data => 'b')
    tree['c'] = Gitrb::Blob.new(:data => 'c')

    id = tree.save

    a = ["2e65efe2a145dda7ee51d1741299f848e5bf752e"].pack('H*')
    b = ["63d8dbd40c23542e740659a7168a0ce3138ea748"].pack('H*')
    c = ["3410062ba67c5ed59b854387a8bc0ec012479368"].pack('H*')

    data =
      "100644 a\0#{a}" +
      "100644 b\0#{b}" +
      "100644 c\0#{c}"

    repo.get(id).should be_a(Gitrb::Tree)
    repo.get(id).names.should include('a')
    repo.get(id).names.should include('b')
    repo.get(id).names.should include('c')
  end

  it "should save trees" do
    tree = Gitrb::Tree.new(:repository => repo)

    tree['a'] = Gitrb::Blob.new(:data => 'a')
    tree['b'] = Gitrb::Blob.new(:data => 'b')
    tree['c'] = Gitrb::Blob.new(:data => 'c')

    tree.save

    ls_tree(tree.id).should ==
      [["100644", "blob", "2e65efe2a145dda7ee51d1741299f848e5bf752e", "a"],
       ["100644", "blob", "63d8dbd40c23542e740659a7168a0ce3138ea748", "b"],
       ["100644", "blob", "3410062ba67c5ed59b854387a8bc0ec012479368", "c"]]
  end

  it "should save nested trees" do
    tree = Gitrb::Tree.new(:repository => repo)

    tree['x/a'] = Gitrb::Blob.new(:data => 'a')
    tree['x/b'] = Gitrb::Blob.new(:data => 'b')
    tree['x/c'] = Gitrb::Blob.new(:data => 'c')

    tree.save

    ls_tree(tree.id).should ==
      [["040000", "tree", "24e88cb96c396400000ef706d1ca1ed9a88251aa", "x"]]

    ls_tree("24e88cb96c396400000ef706d1ca1ed9a88251aa").should ==
      [["100644", "blob", "2e65efe2a145dda7ee51d1741299f848e5bf752e", "a"],
       ["100644", "blob", "63d8dbd40c23542e740659a7168a0ce3138ea748", "b"],
       ["100644", "blob", "3410062ba67c5ed59b854387a8bc0ec012479368", "c"]]
  end
end
