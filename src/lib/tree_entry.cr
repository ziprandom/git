module Git
  class TreeEntry
    getter safe : Safe::TreeEntry::Type

    def initialize(@safe)
    end
  end
end
