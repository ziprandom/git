module Git
  class Commit
    getter repo : Repo
    getter safe : Safe::Commit::Type

    def initialize(@repo, @safe)
    end

    @id      : String?
    @message : String?
    @author  : Signature?

    #
    # the commit message
    #
    def message : String
      @message ||= Safe.string(:commit_message_raw, @safe)
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

    def to_tree : Tree
      Safe.call :commit_tree, out tree, @safe
      Tree.new(@repo, Safe::Tree.free(tree))
    end
  end
end
