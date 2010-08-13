require 'gitrb'
require 'grit'
require 'benchmark'
require 'fileutils'

REPO = '/tmp/gitrb'

FileUtils.rm_rf REPO
FileUtils.mkpath REPO
Dir.chdir REPO

repo = Gitrb::Repository.new(:path => REPO, :create => true)

grit = nil
gitrb = nil

Benchmark.bm 20 do |x|
  x.report 'store 1000 objects' do
    repo.transaction { 'aaa'.upto('jjj') { |key| repo.root[key] = Gitrb::Blob.new(:data => rand.to_s) } }
  end
  x.report 'commit one object' do
    repo.transaction { repo.root['aa'] = Gitrb::Blob.new(:data => rand.to_s) }
  end
  x.report 'init gitrb' do
    gitrb = Gitrb::Repository.new(:path => '.')
  end
  x.report 'init grit' do
    grit = Grit::Repo.new('.')
  end
  x.report 'load 1000 with gitrb' do
    gitrb.root.values.each { |v| v.data }
  end
  x.report 'load 1000 with grit' do
    grit.tree.contents.each { |e| e.data }
  end
end

