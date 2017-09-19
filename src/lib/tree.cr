module Git
  class Tree
    getter safe : Safe::Tree::Type
    getter repo : Repo

    def initialize(@repo, @safe)
    end

    #
    # Diff the tree against another tree or the empty
    # tree if other is undefined in the given Repo
    #
    def diff_to_tree(other : self? = nil) : Git::Diff
      Safe.call :diff_tree_to_tree,
                out diff, @repo.safe,
                    safe, other.try &.safe, nil

      Git::Diff.new Git::Safe::Diff.free diff
    end

    #
    # Lookup the given path in the tree
    #
    def lookup_path(path : String, type : Git::C::Otype? = nil)
      Safe.call :object_lookup_bypath,
        out object, @safe.to_unsafe.as(Git::C::X_Object),
            path, type
      Git::Object.new @repo, Git::Safe::Object.free object
    end
  end
end
