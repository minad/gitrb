module Gitrb

  class Diff
    attr_reader :from, :to, :patch, :deletions, :insertions

    def initialize(from, to, patch)
      @from = from
      @to = to
      @patch = patch
      @deletions = @insertions = 0
      @patch.split("\n").each do |line|
        if line[0..0] == '-'
          @deletions += 1
        elsif line[0..0] == '+'
          @insertions += 1
        end
      end
    end
  end

end
