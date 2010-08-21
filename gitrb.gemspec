Gem::Specification.new do |s|
  s.name = 'gitrb'
  s.version = '0.1.8'
  s.summary = 'Pure ruby git implementation'
  s.author = 'Daniel Mendler'
  s.email = 'mail@daniel-mendler.de'
  s.homepage = 'https://github.com/minad/gitrb'
  s.rubyforge_project = %q{gitrb}
  s.description = 'Fast and lightweight ruby git implementation'
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']
  s.files = %w{
LICENSE
README.md
Rakefile
gitrb.gemspec
lib/gitrb.rb
lib/gitrb/blob.rb
lib/gitrb/commit.rb
lib/gitrb/gitobject.rb
lib/gitrb/pack.rb
lib/gitrb/reference.rb
lib/gitrb/repository.rb
lib/gitrb/tag.rb
lib/gitrb/tree.rb
lib/gitrb/trie.rb
lib/gitrb/user.rb
lib/gitrb/util.rb
test/bare_repository_test.rb
test/benchmark.rb
test/commit_test.rb
test/helper.rb
test/profile.rb
test/repository_test.rb
test/trie_test.rb
test/tree_test.rb
}
  s.add_development_dependency('bacon')
end
