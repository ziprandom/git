module Git
  class Patch
    getter safe : Safe::Patch::Type

    def initialize(@safe); end

    def to_s
      lines = Array(String).new

      cb = Proc(C::DiffDelta*, C::DiffHunk*, C::DiffLine*, Void*, LibC::Int).new do |delta, hunk, line, payload|
        payload.as(Pointer(Array(String))).value.as(Array(String)) << (
          ({"-", "+"}).includes?(line.value.origin) ? line.value.origin.to_s : ""
        ) + String.new line.value.content
        0
      end

      Safe.call :patch_print, @safe, cb, pointerof(lines)
      lines.join("\n")
    end

  end
end
