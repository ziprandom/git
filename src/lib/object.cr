module Git
  class Object
    getter safe : Safe::Object::Type

    def initialize(@safe)
    end

    def self.blob_from_string(repo, content : String)
      Safe.call :blob_create_frombuffer, out oid, repo.safe, content, content.size
      Oid.new Safe::Oid.value oid
    end

    def type
      C.object_type safe
    end

    def commit?
      type == C::Otype::ObjCommit
    end

    def tree?
      type == C::Otype::ObjTree
    end

    def blob?
      type == C::Otype::ObjBlob
    end

    def tag?
      type == C::Otype::ObjTag
    end

    def id
      Oid.new(Safe::Oid.value(C.object_id(@safe).value))
    end

    #
    # Get the Objects content, raises Error unless the Object is a
    # `C::X_Blob`
    #
    def content
      raise "not a Blob object" unless blob?
      s = Git::C.blob_rawsize(safe.to_unsafe.as(Git::C::X_Blob))
      c = Git::C.blob_rawcontent(safe.to_unsafe.as(Git::C::X_Blob)).as(Pointer(UInt8))
      String.new Slice.new(c, s)
    end

    #
    # def filtered_content(path)
    #   raise "not a Blob object" unless blob?
    #   C.blob_filtered_content out buf, safe.to_unsafe.as(Git::C::X_Blob), path.to_unsafe, 1
    #   s = String.new(
    #     Slice.new(
    #       buf.ptr, buf.size
    #     )
    #   )
    #   C.buf_free pointerof(buf)
    #   s
    # end
  end
end
