Gem.activate 'diff-lcs'
require 'gitrb'
require 'fileutils'
require 'grit'
require 'ruby-prof'

REPO = '/tmp/gitrb'

FileUtils.rm_rf REPO
FileUtils.mkpath REPO

repo = Gitrb::Repository.new(:path => REPO, :create => true)
repo.transaction { 'aaa'.upto('jjj') { |key| repo.root[key] = Gitrb::Blob.new(:data => rand.to_s) } }

result = RubyProf.profile do
  Gitrb::Repository.new(:path => '.').root.values { |v| v }
end

printer = RubyProf::GraphHtmlPrinter.new(result)
printer.print(File.open('gitrb.html', 'w'), :min_percent => 10)

result = RubyProf.profile do
  Grit::Repo.new(:path => '.').tree.contents.each { |e| e.data }
end

printer = RubyProf::GraphHtmlPrinter.new(result)
printer.print(File.open('grit.html', 'w'), :min_percent => 10)
