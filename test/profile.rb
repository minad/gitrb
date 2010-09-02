require 'gitrb'
require 'fileutils'
require 'grit'
require 'ruby-prof'

REPO_PATH = '/tmp/gitrb_test'

FileUtils.rm_rf REPO_PATH
FileUtils.mkpath REPO_PATH

repo = Gitrb::Repository.new(:path => REPO_PATH, :create => true)
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
