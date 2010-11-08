# -*- encoding: utf-8 -*-
require File.dirname(__FILE__) + "/lib/gitrb/version"
require 'date'

Gem::Specification.new do |s|
  s.name = 'gitrb'
  s.version = Gitrb::VERSION
  s.summary = 'Pure ruby git implementation'
  s.date    = Date.today.to_s
  s.author = 'Daniel Mendler'
  s.email = 'mail@daniel-mendler.de'
  s.homepage = 'https://github.com/minad/gitrb'
  s.rubyforge_project = %q{gitrb}
  s.description = 'Fast and lightweight ruby git implementation'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency('bacon')
end
