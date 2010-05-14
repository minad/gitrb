module Gitrb

  class User < Struct.new(:name, :email, :date)
    def initialize(name, email, date = Time.now)
      super
    end

    def dump
      off = date.gmt_offset / 60
      '%s <%s> %d %s%02d%02d' % [name, email, date.to_i, off < 0 ? '-' : '+', off / 60, off % 60]
    end

    def self.parse(user)
      if match = user.match(/(.*)<(.*)> (\d+) ([+-]?\d+)/)
        new match[1].strip, match[2].strip, Time.at(match[3].to_i)
      end
    end

  end

end
