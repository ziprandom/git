module Git
  class Signature
    getter safe : Safe::Signature::Type

    @name : String?
    @email : String?
    @time : Int32?

    def initialize(@safe)
    end

    #
    # Initialize a new signature with name and email
    #
    def initialize(name : String, email : String)
      Safe.call :signature_new, out safe, name, email, Time.now.epoch, 0
      @safe = Safe::Signature.free safe
    end

    #
    # The name associated with the signature
    #
    def name : String
      @name ||= String.new @safe.value.name
    end

    #
    # The email associated with the signature
    #
    def email : String
      @email ||= String.new @safe.value.email
    end

    #
    # The time associated with the signature
    #
    def time : Int32
      @time ||= @safe.value.when.time.to_i32
    end
  end
end
