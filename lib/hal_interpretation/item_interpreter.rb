module HalInterpretation
  class ItemInterpreter
    # opts - named args
    #   :location - 
    #   :interpreter - 
    def initialize(a_representation, opts)
      @repr = a_representation
      @location = opts.fetch(:location) { fail ArgumentError, "location is required" }
      @problems = []
      @interpreter = opts.fetch(:interpreter) { fail ArgumentError, "interpreter is required" }
    end

    def items
      interpret unless done?

      (raise InvalidRepresentationError.new problems) if problems.any?

      @items
    end

    def problems
      interpret unless done?

      @problems
    end

    protected

    extend Forwardable

    def_delegators :interpreter, :extractors, :extractor_for

    attr_reader :repr, :location, :interpreter

    def done?
      !@items.nil? || @problems.any?
    end

    def interpret
      new_item = interpreter.new_item do |it|
        e = extractors
        e.each do |an_extractor|
          @problems += an_extractor.extract(from: repr, to: it, context: interpreter)
            .map {|msg| "#{json_path_for an_extractor.attr} #{msg}" }
        end
      end

      apply_validations(new_item)

      return if @problems.any?

      @items = [new_item]
    end

    def apply_validations(an_item)
      an_item.valid?

      an_item.errors.each do |attr, msg|
        leader = begin
                   json_path_for attr
                 rescue KeyError
                   "#{attr} [which is not directly extracted from JSON]"
                 end

        @problems << leader + " " + msg
      end
    end

    def json_path_for(attr)
      extractor = extractor_for(attr)
      raise KeyError unless extractor

      json_pointer_join(location, extractor.location)
    end

    def json_pointer_join(head, tail)
      head = head[0..-2] if head.end_with?("/")
      tail = tail[1..-1] if tail.start_with?("/")

      head + "/" + tail
    end
  end

end
