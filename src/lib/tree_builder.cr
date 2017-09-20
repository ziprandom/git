module Git

  alias Filemode = C::FilemodeT

  class TreeBuilder
    getter safe : Safe::TreeBuilder::Type
    getter repo : Repo

    def initialize(@repo, source : Tree? = nil)
      Safe.call :treebuilder_new, out treebuilder, @repo.safe, source.safe.p
      @safe = Safe::TreeBuilder.free treebuilder
    end

    def initialize(@repo, @safe); end

    def add(oid : Git::Oid, filename : String, filemode : C::FilemodeT)
      Safe.call(:treebuilder_insert, out entry, @safe, filename, oid.safe.p, filemode)
      TreeEntry.new Safe::TreeEntry.free entry
    end

    def entry_count
      C.treebuilder_entrycount(@safe)
    end

    def write
      Safe.call :treebuilder_write, out oid, safe
      Oid.new(Safe::Oid.value(oid))
    end
  end
end
