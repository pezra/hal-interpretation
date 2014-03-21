module HalInterpretation
  Error = Class.new(StandardError)

  class InvalidRepresentationError < Error
    # Initializes a new instance of this error
    #
    # problems - list of problems detected with the representation.
    def initialize(problems)
      @problems = problems = Array(problems)

      msg = problems.first
      msg += " and #{problems.count - 1} more problems" if problems.count > 1

      super msg
    end

    attr_reader :problems
  end
end
