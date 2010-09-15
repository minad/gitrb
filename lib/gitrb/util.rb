module Gitrb
  module Util
    if RUBY_VERSION > '1.9'
      def self.read_bytes_until(io, char)
        str = ''
        while ((ch = io.getc) != char) && !io.eof
          str << ch
        end
        str
      end
    else
      def self.read_bytes_until(io, char)
        str = ''
        while ((ch = io.getc.chr) != char) && !io.eof
          str << ch
        end
        str
      end
    end
  end
end

# str[0] returns a 1-char string in Ruby 1.9 but a
# Fixnum in 1.8.  Monkeypatch a fix if we're on 1.8.
if !1.respond_to?(:ord)
  class Fixnum
    def ord
      self
    end
  end
end
