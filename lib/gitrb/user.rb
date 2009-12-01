module Gitrb

  class User
    attr_accessor :name, :email, :date

    def initialize(name, email, date = Time.now)
      @name, @email, @date = name, email, date
    end

    def dump
      "#{name} <#{email}> #{date.localtime.to_i} #{date.gmt_offset < 0 ? '-' : '+'}#{date.gmt_offset / 60}"
    end

    def self.parse(user)
      if match = user.match(/(.*)<(.*)> (\d+) ([+-]?\d+)/)
        new match[1].strip, match[2].strip, Time.at(match[3].to_i)
      end
    end

  end

end
