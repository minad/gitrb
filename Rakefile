require 'rake'
require 'rake/rdoctask'

task :default => :test

desc 'Run tests with bacon'
task :test => FileList['test/*_test.rb'] do |t|
  sh "bacon -q -Ilib:test #{t.prerequisites.join(' ')}"
end

desc "Generate the RDoc"
Rake::RDocTask.new do |rdoc|
  files = ["README.md", "LICENSE", "lib/**/*.rb"]
  rdoc.rdoc_files.add(files)
  rdoc.main = "README.md"
  rdoc.title = "Gitrb"
end
