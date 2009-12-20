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
