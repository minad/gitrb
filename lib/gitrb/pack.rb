#
# converted from the gitrb project
#
# authors:
#    Matthias Lederhofer <matled@gmx.net>
#    Simon 'corecode' Schubert <corecode@fs.ei.tum.de>
#    Scott Chacon <schacon@gmail.com>
#
# provides native ruby access to git objects and pack files
#

module Gitrb
  PACK_SIGNATURE = "PACK"
  PACK_IDX_SIGNATURE = "\377tOc"

  OBJ_NONE = 0
  OBJ_COMMIT = 1
  OBJ_TREE = 2
  OBJ_BLOB = 3
  OBJ_TAG = 4

  OBJ_TYPES = [nil, 'commit', 'tree', 'blob', 'tag'].freeze

  class FileWindow
    def initialize(file, version = 1)
      @file = file
      @offset = nil
      if version == 2
        @global_offset = 8
      else
        @global_offset = 0
      end
    end

    def [](offset, len)
      @file.seek(offset + @global_offset) if @offset != offset
      @offset = offset + len
      @file.read(len)
    end
  end

  class PackFormatError < StandardError; end

  class Pack
    OBJ_OFS_DELTA = 6
    OBJ_REF_DELTA = 7

    FanOutCount = 256
    SHA1Size = 20
    IdxOffsetSize = 4
    OffsetSize = 4
    CrcSize = 4
    OffsetStart = FanOutCount * IdxOffsetSize
    SHA1Start = OffsetStart + OffsetSize
    EntrySize = OffsetSize + SHA1Size
    EntrySizeV2 = SHA1Size + CrcSize + OffsetSize

    attr_reader :name

    def initialize(file)
      file = file[0...-3] + 'pack' if file =~ /\.idx$/
      @name = file
      init_pack
    end

    def each_object
      with_idx do |idx|
        if @version == 2
          data = read_data_v2(idx)
          data.each do |sha1, crc, offset|
            sha1 = sha1.unpack("H*").first
            yield sha1, offset
          end
        else
          pos = OffsetStart
          @size.times do
            offset = idx[pos,OffsetSize].unpack('N')[0]
            sha1 = idx[pos+OffsetSize,SHA1Size]
            pos += EntrySize
            sha1 = sha1.unpack("H*").first
            yield sha1, offset
          end
        end
      end
    end

    def get_object(offset)
      data, type = with_pack do |packfile|
        unpack_object(packfile, offset)
      end
      [data, OBJ_TYPES[type]]
    end

    private

    def with_idx
      idxfile = File.open(@name[0...-4]+'idx', 'rb')

      sig = idxfile.read(4)
      ver = idxfile.read(4).unpack("N")[0]

      if sig == PACK_IDX_SIGNATURE
        if(ver != 2)
          raise PackFormatError, "pack #@name has unknown pack file version #{ver}"
        end
        @version = 2
      else
        @version = 1
      end

      idx = FileWindow.new(idxfile, @version)
      result = yield idx
      idxfile.close
      result
    end

    def with_pack
      packfile = File.open(@name, 'rb')
      result = yield packfile
      packfile.close
      result
    end

    def init_pack
      with_idx do |idx|
        @offsets = [0]
        FanOutCount.times do |i|
          pos = idx[i * IdxOffsetSize,IdxOffsetSize].unpack('N')[0]
          if pos < @offsets[i]
            raise PackFormatError, "pack #@name has discontinuous index #{i}"
          end
          @offsets << pos
        end
        @size = @offsets[-1]
      end
    end

    def read_data_v2(idx)
      data = []
      pos = OffsetStart
      @size.times do |i|
        data[i] = [idx[pos,SHA1Size], 0, 0]
        pos += SHA1Size
      end
      @size.times do |i|
        crc = idx[pos,CrcSize]
        data[i][1] = crc
        pos += CrcSize
      end
      @size.times do |i|
        offset = idx[pos,OffsetSize].unpack('N')[0]
        data[i][2] = offset
        pos += OffsetSize
      end
      data
    end

    def find_object(sha1)
      with_idx do |idx|
        slot = sha1[0].ord
        return nil if !slot
        first, last = @offsets[slot,2]
        while first < last
          mid = (first + last) / 2
          if @version == 2
            midsha1 = idx[OffsetStart + (mid * SHA1Size), SHA1Size]
            cmp = midsha1 <=> sha1

            if cmp < 0
              first = mid + 1
            elsif cmp > 0
              last = mid
            else
              pos = OffsetStart + (@size * (SHA1Size + CrcSize)) + (mid * OffsetSize)
              offset = idx[pos, OffsetSize].unpack('N')[0]
              return offset
            end
          else
            midsha1 = idx[SHA1Start + mid * EntrySize,SHA1Size]
            cmp = midsha1 <=> sha1

            if cmp < 0
              first = mid + 1
            elsif cmp > 0
              last = mid
            else
              pos = OffsetStart + mid * EntrySize
              offset = idx[pos,OffsetSize].unpack('N')[0]
              return offset
            end
          end
        end
        nil
      end
    end

    def unpack_object(packfile, offset)
      obj_offset = offset
      packfile.seek(offset)

      c = packfile.read(1)[0].ord
      size = c & 0xf
      type = (c >> 4) & 7
      shift = 4
      offset += 1
      while c & 0x80 != 0
        c = packfile.read(1)[0].ord
        size |= ((c & 0x7f) << shift)
        shift += 7
        offset += 1
      end

      case type
      when OBJ_OFS_DELTA, OBJ_REF_DELTA
        data, type = unpack_deltified(packfile, type, offset, obj_offset, size)
      when OBJ_COMMIT, OBJ_TREE, OBJ_BLOB, OBJ_TAG
        data = unpack_compressed(offset, size)
      else
        raise PackFormatError, "invalid type #{type}"
      end
      [data, type]
    end

    def unpack_deltified(packfile, type, offset, obj_offset, size)
      packfile.seek(offset)
      data = packfile.read(SHA1Size)

      if type == OBJ_OFS_DELTA
        i = 0
        c = data[i].ord
        base_offset = c & 0x7f
        while c & 0x80 != 0
          c = data[i += 1].ord
          base_offset += 1
          base_offset <<= 7
          base_offset |= c & 0x7f
        end
        base_offset = obj_offset - base_offset
        offset += i + 1
      else
        base_offset = find_object(data)
        offset += SHA1Size
      end

      base, type = unpack_object(packfile, base_offset)

      delta = unpack_compressed(offset, size)
      [patch_delta(base, delta), type]
    end

    def unpack_compressed(offset, destsize)
      outdata = ""
      with_pack do |packfile|
        packfile.seek(offset)
        zstr = Zlib::Inflate.new
        while outdata.size < destsize
          indata = packfile.read(0xFFFF)
          if indata.size == 0
            raise PackFormatError, 'error reading pack data'
          end
          outdata << zstr.inflate(indata)
        end
        if outdata.size > destsize
          raise PackFormatError, 'error reading pack data'
        end
        zstr.close
      end
      outdata
    end

    def patch_delta(base, delta)
      src_size, pos = patch_delta_header_size(delta, 0)
      if src_size != base.size
        raise PackFormatError, 'invalid delta data'
      end

      dest_size, pos = patch_delta_header_size(delta, pos)
      dest = ""
      while pos < delta.size
        c = delta[pos].ord
        pos += 1
        if c & 0x80 != 0
          pos -= 1
          cp_off = cp_size = 0
          cp_off = delta[pos += 1].ord if c & 0x01 != 0
          cp_off |= delta[pos += 1].ord << 8 if c & 0x02 != 0
          cp_off |= delta[pos += 1].ord << 16 if c & 0x04 != 0
          cp_off |= delta[pos += 1].ord << 24 if c & 0x08 != 0
          cp_size = delta[pos += 1].ord if c & 0x10 != 0
          cp_size |= delta[pos += 1].ord << 8 if c & 0x20 != 0
          cp_size |= delta[pos += 1].ord << 16 if c & 0x40 != 0
          cp_size = 0x10000 if cp_size == 0
          pos += 1
          dest << base[cp_off,cp_size]
        elsif c != 0
          dest << delta[pos,c]
          pos += c
        else
          raise PackFormatError, 'invalid delta data'
        end
      end
      dest
    end

    def patch_delta_header_size(delta, pos)
      size = 0
      shift = 0
      begin
        c = delta[pos].ord
        if c == nil
          raise PackFormatError, 'invalid delta header'
        end
        pos += 1
        size |= (c & 0x7f) << shift
        shift += 7
      end while c & 0x80 != 0
      [size, pos]
    end
  end
end
