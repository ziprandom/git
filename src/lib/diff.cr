module Git
  alias DiffFormat = C::DiffFormatT

  class Diff
    getter safe : Safe::Diff::Type

    def initialize(@safe)
    end

    def empty?
      size == LibC::SizeT.zero
    end

    def size
      C.diff_num_deltas(@safe)
    end

    def each
      i = LibC::SizeT.zero
      while i < size
        yield delta_at(i)
        i += 1
      end
    end

    def delta_at(index : LibC::SizeT)
      DiffDelta.new(Safe::DiffDelta.unfree(C.diff_get_delta(@safe, index)))
    end

    def to_s
      to_patches.map(&.to_s).to_a.join("\n\n")
    end

    def to_patches
      patches = [] of Patch
      size.times.each do |idx|
        Safe.call :patch_from_diff, out patch, @safe, idx
        patches << Patch.new Safe::Patch.free patch
      end
      patches
    end
  end
end
