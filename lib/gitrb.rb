require 'zlib'
require 'digest/sha1'
require 'fileutils'
require 'logger'
require 'enumerator'
require 'stringio'

require 'gitrb/util'
require 'gitrb/gitobject'
require 'gitrb/reference'
require 'gitrb/blob'
require 'gitrb/diff'
require 'gitrb/tree'
require 'gitrb/tag'
require 'gitrb/user'
require 'gitrb/pack'
require 'gitrb/commit'
require 'gitrb/trie'
require 'gitrb/repository'

# str[0] returns a 1-char string in Ruby 1.9 but a
# Fixnum in 1.8.  Monkeypatch a fix if we're on 1.8.
if !1.respond_to?(:ord)
  class Fixnum
    def ord
      self
    end
  end
end
