module Git
  class Commit
    getter repo : Repo
    getter safe : Safe::Commit::Type

    def initialize(@repo, @safe)
    end

    def initialize(@repo, oid : Oid)
      Safe.call :commit_lookup, out commit, @repo.safe, oid.safe.p
      @safe = Safe::Commit.free commit
    end

    @id      : String?
    @message : String?
    @author  : Signature?
    @committer  : Signature?
    @time    : Int32?

    #
    # the commit message
    #
    def message : String
      @message ||= Safe.string(:commit_message_raw, @safe)
    end

    #
    # get the parents of this commit
    #
    def parents : Array(Commit)
      parentcount = C.commit_parentcount(@safe).to_i32
      parentcount.times.to_a.map do |index|
        Safe.call :commit_parent, out commit, @safe, index
        self.class.new @repo, Safe::Commit.free commit
      end
    end

    #
    # Format the Commit as an Email
    #
    def as_email
      Safe.call :diff_init_options, out options, 1
      buf = C::Buf.allocate
      Safe.call :diff_commit_as_email, pointerof(buf), @repo.safe, @safe, 1, 1, C::DiffFormatEmailFlagsT::DiffFormatEmailExcludeSubjectPatchMarker, pointerof(options)
      String.new Slice.new buf.ptr, buf.size
    end

    #
    # the commit hash
    #
    def id : String
      @id ||= Safe.string :oid_tostr_s, C.commit_id(@safe)
    end

    #
    # the authors signature
    #
    def author : Signature
      @author ||= Signature.new(Safe::Signature.free C.commit_author(@safe))
    end

    #
    # the commiter signature
    #
    def committer : Signature
      @committer ||= Signature.new(Safe::Signature.free C.commit_committer(@safe))
    end

    #
    # Timestamp for this commit unix epoch
    #
    def time : Int32
      @time ||= C.commit_time(@safe).to_i32
    end

    def to_tree : Tree
      Safe.call :commit_tree, out tree, @safe
      Tree.new(@repo, Safe::Tree.free(tree))
    end
  end
end
