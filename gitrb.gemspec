Gem::Specification.new do |s|
  s.name = 'gitrb'
  s.version = '0.0.1'
  s.summary = 'Pure ruby git implementation'
  s.author = 'Daniel Mendler'
  s.email = 'mail@daniel-mendler.de'
  s.homepage = 'https://github.com/minad/gitrb'
  s.description = <<END
Pure ruby git implementation similar to grit.
END
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']  
  s.files = %w{
.gitignore
LICENSE
README.md
Rakefile
gitrb.gemspec
lib/gitrb.rb
lib/gitrb/blob.rb
lib/gitrb/commit.rb
lib/gitrb/diff.rb
lib/gitrb/pack.rb
lib/gitrb/tag.rb
lib/gitrb/tree.rb
lib/gitrb/user.rb
lib/gitrb/trie.rb
test/bare_repository_spec.rb
test/benchmark.rb
test/commit_spec.rb
test/repository_spec.rb
test/trie_spec.rb
test/tree_spec.rb
}
end

