require "#{File.dirname(__FILE__)}/../lib/gitrb"
require 'pp'

describe Gitrb::Trie do

  it "should add children" do
    trie = Gitrb::Trie.new
    0.upto(100) do |i|
      trie.insert('a' * i, i)
    end
    trie.find('').key.should == ''
    trie.find('').value.should == 0
    1.upto(100) do |i|
      trie.find('a' * i).key.should == 'a'
      trie.find('a' * i).value.should == i
    end
  end

  it "should split node" do
    trie = Gitrb::Trie.new
    trie.insert("abc", 1)
    trie.insert("ab", 2)
    trie.insert("ac", 3)
  end

end
