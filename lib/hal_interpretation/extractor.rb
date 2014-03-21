require 'hana'

module HalInterpretation
  class Extractor
    # opts - named args
    #   :attr - name of attribute this object will extact.
    #   :location - JSON path from which to get the value.
    def initialize(opts) #attr:, location: "/#{attr}")
      @attr = opts.fetch(:attr) { fail ArgumentError, "attr is required" }
      @location = opts.fetch(:location) { "/#{attr}" }
      @pointer = Hana::Pointer.new(location)
    end

    # opts - named args
    #   :from - The HalRepresentation from which to extract attribute.
    #   :to - The model that we are extracting
    #
    # Returns any problems encountered.
    def extract(opts)
      from = opts.fetch(:from) { fail ArgumentError, "from is required" }
      to = opts.fetch(:to) { fail ArgumentError, "to is required" }
      to.send "#{attr}=", pointer.eval(from)

      []
    rescue => err
      [err.message]
    end

    attr_reader :attr, :location

    protected
    attr_reader :pointer
  end
end