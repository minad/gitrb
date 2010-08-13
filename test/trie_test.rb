require 'gitrb'

describe Gitrb::Trie do

  before do
    @trie = Gitrb::Trie.new
  end

  it 'should be empty' do
    @trie.should.be.empty
    @trie.to_a.should.be.empty
    @trie.size.should.equal 0
    @trie.find('').should.be.identical_to @trie
    @trie.find('abc').should.be.identical_to @trie
  end

  it 'should find by prefix' do
    @trie.insert('abcdef', 1)
    @trie.find('a').should.be.identical_to @trie.find('abcdef')
    @trie.find('abc').should.be.identical_to @trie.find('abcdef')
    @trie.find('abc').key.should.equal 'abcdef'
  end

  it 'should have clear' do
    @trie.insert('abc', 1)
    @trie.should.not.be.empty
    @trie.clear
    @trie.should.be.empty
  end

  it 'should split shorter node' do
    @trie.insert('a', 1)
    @trie.key.should.equal 'a'
    @trie.value.should.equal 1
    @trie.size.should.equal 1
    @trie.find('a').should.be.identical_to @trie

    @trie.insert('b', 2)
    @trie.children.size.should.equal 2
    @trie.key.should.equal ''
    @trie.value.should.be.nil
    @trie.size.should.equal 2
    @trie.find('a').key.should.equal 'a'
    @trie.find('b').key.should.equal 'b'
    @trie.size.should.equal 2
  end

  it 'should add child' do
    @trie.insert('a', 1)

    @trie.insert('ab', 2)
    @trie.size.should.equal 2
    @trie.children.size.should.equal 1
    @trie.find('a').children.size.should.equal 1
    @trie.find('a').key.should.equal 'a'
    @trie.find('a').value.should.equal 1
    @trie.find('ab').key.should.equal 'ab'
    @trie.find('ab').value.should.equal 2
  end

  it 'should overwrite value' do
    @trie.insert('a', 1)
    @trie.insert('a', 2)
    @trie.find('a').value.should.equal 2
    @trie.size.should.equal 1
  end

  it 'should add second-level child' do
    @trie.insert('a', 1)
    @trie.insert('ab', 2)
    @trie.insert('abc', 3)

    @trie.find('a').children.size.should.equal 1
    @trie.find('ab').children.size.should.equal 1
    @trie.find('abc').value.should.equal 3
    @trie.size.should.equal 3
  end

  it 'set value of empty node' do
    @trie.insert('a', 1)
    @trie.insert('b', 2)
    @trie.size.should.equal 2
    @trie.insert('', 3)
    @trie.value.should.equal 3
    @trie.size.should.equal 3
  end

  it 'should split longer node' do
    @trie.insert('ab', 1)
    @trie.size.should.equal 1
    @trie.insert('a', 2)
    @trie.size.should.equal 2
    @trie.find('ab').value.should.equal 1
    @trie.find('a').value.should.equal 2
  end
end
