module Git
  class Repo
    getter safe : Safe::Repository::Type
    property? credential : Credentials::Base?
    property? signature : Signature?
    property? merge_options : MergeOptions?
    property? checkout_options : CheckoutOptions?
    property? rebase_options : RebaseOptions?
    property? diff_options : DiffOptions?

    private def initialize(@safe)
    end

    def self.open?(path : String)
      begin
        open(path)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Enotfound
      rescue NotExactLocation
      end
    end

    def self.open(path : String)
      Safe.call :repository_open, out repo, path do |call|
        if call.success?
          git = new(Safe::Repository.free(repo))
          expected = File.real_path(path)
          actual = File.real_path(git.path)
          raise NotExactLocation.new(expected, actual) unless actual.starts_with?(expected)
          git
        else
          call.raise!
        end
      end
    end

    def self.init(path : String, bare = false)
      Safe.call :repository_init, out repo, path, bare ? 1 : 0
      new(Safe::Repository.free(repo))
    end

    @path : String?
    def path
      @path ||= Safe.string(:repository_path, @safe)
    end

    @remotes : Hash(String, Remote)?
    def remotes
      @remotes ||= ({} of String => Remote).tap do |h|
        a = uninitialized C::Strarray
        Safe.call :remote_list, pointerof(a), @safe
        Strarray.new(Safe::Strarray.unfree(pointerof(a))).each do |name|
          h[name] = lookup_remote(name)
        end
      end
    end

    def lookup_or_create_remote(name : String, url : String)
      lookup_remote?(name) || create_remote(name, url)
    end

    def create_remote(name : String, url : String)
      Safe.call :remote_create, out unsafe, @safe, name, url
      update_remotes
      Remote.new(self, Safe::Remote.free(unsafe), name)
    end

    # Creates a new remote.
    #
    # Does nothing if the remote exists.
    def create_remote?(name : String, url : String)
      begin
        create_remote(name, url)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Eexists
      end
    end

    # :nodoc:
    def update_remotes
      @remotes = nil
    end

    def lookup_remote(name)
      Safe.call :remote_lookup, out remote, @safe, name
      Remote.new(self, Safe::Remote.free(remote), name)
    end

    def lookup_remote?(name)
      begin
        lookup_remote(name)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Enotfound
      end
    end

    def parse_rev(spec : String)
      Safe.call :revparse_single, out obj, @safe, spec
      Object.new(Safe::Object.free(obj))
    end

    def parse_rev?(spec : String)
      begin
        parse_rev(spec)
      rescue ex : Safe::CallError
        raise ex if call.result != C::Enotfound
      end
    end

    def lookup_ref(name)
      Safe.call :reference_dwim, out ref, @safe, name
      Ref.new(self, Safe::Reference.free(ref))
    end

    def lookup_ref?(name)
      begin
        lookup_ref(name)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Enotfound
      end
    end

    def lookup_object(oid : Oid, type : C::Otype = C::Otype::ObjAny)
      Safe.call :object_lookup, out obj, @safe, oid.safe.p, type
      Object.new(Safe::Object.free(obj))
    end

    def head
      Safe.call :repository_head, out ref, @safe
      Ref.new(self, Safe::Reference.free(ref))
    end

    def head?
      begin
        head
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Eunbornbranch
      end
    end

    def set_head(refname : String)
      Safe.call :repository_set_head, @safe, refname
    end

    def set_head(oid : Oid)
      Safe.call :repository_set_head_detached, @safe, oid.safe.p
    end

    def set_head(commit : AnnotatedCommit)
      Safe.call :repository_set_head_detached_from_annotated, @safe, commit.safe
    end

    def create_ref(name : String, oid : Oid, force = false)
      Safe.call :reference_create, out ref, @safe, name, oid.safe.p, force ? 1 : 0, Util.null_pstr
      Ref.new(self, Safe::Reference.free(ref))
    end

    # Creates a reference that points to HEAD.
    #
    # Creates a initial commit first if the head is unborn.
    def create_ref(name : String, initial_commit_message : String? = "initial", signature : Signature? = nil, force = false)
      raise "invalid refname #{name}" unless Safe.call :reference_is_valid_name, name
      unless head?
        set_head(
          create_commit message: initial_commit_message, update_ref: nil, signature: signature
        )
      end
      create_ref(name, head.to_oid, force: force)
    end

    def ref_to_oid(name : String)
      Safe.call :reference_name_to_id, out oid, @safe, name
      Oid.new(Safe::Oid.value(oid))
    end

    def ref_to_oid?(name : String)
      begin
        ref_to_oid(name)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Enotfound
      end
    end

    def checkout(ref : Ref, name_as : String? = nil, options : CheckoutOptions? = nil)
      options ||= checkout_options? || CheckoutOptions.new
      Safe.call :checkout_tree, @safe, parse_rev("#{ref.name}^{tree}").safe, options.p
    end

    def checkout_head(options : CheckoutOptions? = nil)
      Safe.call :checkout_head, @safe, (options || checkout_options).p
    end

    def lookup_commit(oid : Oid)
      Safe.call :commit_lookup, out commit, @safe, oid.safe.p
      Commit.new(self, Safe::Commit.free(commit))
    end

    def lookup_commit?(oid : Oid)
      begin
        lookup_commit(oid)
      rescue ex : Safe::CallError
        raise ex if ex.result != C::Enotfound
      end
    end

    def get_annotated_commit(ref : Ref)
      Safe.call :annotated_commit_from_ref, out commit, @safe, ref.safe
      AnnotatedCommit.new(self, Safe::AnnotatedCommit.free(commit))
    end

    def rebase(upstream : AnnotatedCommit, branch : AnnotatedCommit? = nil, onto : AnnotatedCommit? = nil, options : RebaseOptions? = nil)
      rebase(upstream: upstream, branch: branch, onto: onto, options: options) {}
    end

    def rebase(upstream : AnnotatedCommit, branch : AnnotatedCommit? = nil, onto : AnnotatedCommit? = nil, options : RebaseOptions? = nil, signature : Signature? = nil, &block)
      safe_branch = branch ? branch.safe : Safe::AnnotatedCommit.null
      safe_onto = onto ? onto.safe : Safe::AnnotatedCommit.null
      options ||= rebase_options? || RebaseOptions.new
      options = options.dup
      signature ||= self.signature? || new_default_signature
      Safe.call :rebase_init, out unsafe_rebase, @safe, safe_branch, upstream.safe, safe_onto, options.p
      rebase = Rebase.new(self, Safe::Rebase.free(unsafe_rebase))
      while rebase.next
        index = options.value.inmemory == 1 ? rebase.inmemory_index : new_index
        yield rebase, index
        if index.has_conflicts?
          rebase.abort
          raise MergeConflict.new
        end
        rebase.commit signature
      end
      rebase.finish signature
    end

    def new_default_signature
      Safe.call :signature_default, out signature, @safe
      Signature.new(Safe::Signature.free(signature))
    end

    def analyze_merge(their : AnnotatedCommit | Array(AnnotatedCommit), preference : C::MergePreferenceT? = nil)
      their = case their
      when AnnotatedCommit
        [their]
      else
        thier
      end
      preference ||= C::MergeAnalysisNone
      Safe.call :merge_analysis, out analysis, preference, their, their.size
      analysis
    end

    def commit_is_descendant_of(commit : Oid, ancestor : Oid)
      Safe.call(:graph_descendant_of, @safe, commit.safe.p, ancestor.safe.p) == 1
    end

    def diff_to_workdir(tree : Tree? = nil, options : DiffOptions? = nil)
      options ||= diff_options? || DiffOptions.new
      tree ||= head.to_commit.to_tree
      Safe.call :diff_tree_to_workdir, out diff, @safe, tree.safe, options.p
      Diff.new(Safe::Diff.free(diff))
    end

    def diff_to_index(tree : Tree? = nil, index : Index? = nil, options : DiffOptions? = nil)
      options ||= diff_options? || DiffOptions.new
      tree ||= head.to_commit.to_tree
      Safe.call :diff_tree_to_index, out diff, @safe, tree.safe, index, options.p
      Diff.new(Safe::Diff.free(diff))
    end

    def reset(commit : AnnotatedCommit, type : C::ResetT, checkout_options : CheckoutOptions? = nil)
      checkout_options ||= checkout_options? || CheckoutOptions.new
      Safe.call :reset_from_annotated, @safe, commit.safe, type, checkout_options.p
    end

    def merge(their : AnnotatedCommit | Array(AnnotatedCommit), options : MergeOptions? = nil, checkout_options : CheckoutOptions? = nil)
      their = case their
      when AnnotatedCommit
        [their]
      else
        thier
      end
      options ||= merge_options || MergeOptions.new
      checkout_options ||= self.checkout_options || CheckoutOptions.new
      Safe.call :merge, @safe, their, their.size, options.p, checkout_options.p
    end

    def new_index
      Safe.call :repository_index, out index, @safe
      Index.new(Safe::Index.free(index))
    end

    def onto(ref : Ref?, type : C::ResetT, checkout_options : CheckoutOptions? = nil, &block)
      if ref
        current = head?
        current_annotated = if current
          current.to_annotated_commit
        end
        set_head ref.name
        reset ref.to_annotated_commit, type: type, checkout_options: checkout_options
        begin
          yield
        ensure
          if current
            if current_annotated
              if current.name == "HEAD"
                set_head current_annotated
              else
                set_head current.name
              end
              reset current_annotated, type: type, checkout_options: checkout_options
            end
          end
        end
      else
        yield
      end
    end

    def create_commit(message : String, update_ref : String? = nil, signature : Signature? = nil, message_encoding : String?= nil, parents : Commit | Array(Commit) | Nil = nil)
      treeid = new_index.write_tree
      tree = lookup_tree(treeid)
      create_commit(tree, message, update_ref: update_ref, signature: signature, message_encoding: message_encoding, parents: parents)
    end

    def lookup_tree(oid : Oid)
      Safe.call :tree_lookup, out tree, @safe, oid.safe.p
      Tree.new(self, Safe::Tree.free(tree))
    end

    def create_commit(tree : Tree, message : String, update_ref : String? = nil, signature : Signature? = nil, message_encoding : String? = nil, parents : Commit | Array(Commit) | Nil = nil)
      parents = case parents
      when Commit
        [parents]
      when Array(Commit)
        parents
      else
        [] of Commit
      end
      signature ||= self.signature? || new_default_signature
      Safe.call :commit_create, out id, @safe, update_ref, signature.safe.p, signature.safe.p, message_encoding, message, tree.safe, parents.size, parents.map{|i| i.safe.to_unsafe}
      Oid.new(Safe::Oid.value(id))
    end

    def ahead_behind(local : Oid, upstream : Oid)
      Safe.call :graph_ahead_behind, out ahead, out behind, @safe, local.safe.p, upstream.safe.p
      {ahead, behind}
    end

    class ReferenceCallbackPayload
      property! repo : Repo
      property! callback : Proc(Ref, Nil)
    end

    @@reference_foreach_name_callback = C::ReferenceForeachNameCb.new do |name, payload|
      this = Box(ReferenceCallbackPayload).unbox(payload)
      if ref = this.repo.lookup_ref?(String.new(name))
        this.callback.call ref
      end
      0
    end

    def each_ref(&block : Ref -> _)
      payload = ReferenceCallbackPayload.new
      payload.repo = self
      payload.callback = block
      Safe.call :reference_foreach_name, @safe, @@reference_foreach_name_callback, Box(ReferenceCallbackPayload).box(payload)
    end

    #
    # An `Iterator` to lazily retrieve commits
    # from `git_revwalk`
    #
    class CommitIterator
      include Iterator(Commit)

      @walk : C::X_Revwalk

      def initialize(@repo : Repo)
        Safe.call :revwalk_new, out @walk, @repo.safe
        C.revwalk_sorting @walk, C::SortTopological | C::SortTime
        if @repo.head?
          Safe.call :revwalk_push_head, @walk
        end
        Safe.call :revwalk_hide_glob, @walk, "tags/*"
      end

      #
      # return the next `Commit` of the Iterator
      #
      def next : Commit | Iterator::Stop
        unless C.revwalk_next(out next_oid, @walk) == 0
          C.revwalk_free @walk if @walk
          return Iterator::Stop::INSTANCE
        end

        C.commit_lookup out commit, @repo.safe, pointerof(next_oid)
        Commit.new @repo, Safe::Commit.free(commit)
      end

    end

    #
    # Iterate over the repositories commits
    #
    def commits : CommitIterator
      CommitIterator.new(self)
    end

  end
end
