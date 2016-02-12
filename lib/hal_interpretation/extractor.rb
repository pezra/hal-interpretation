require 'hana'

module HalInterpretation
  class Extractor
    # opts - named args
    #   :attr - name of attribute this object will extact.
    #
    #   :location - JSON path from which to get the value.
    #
    #   :extraction_proc - Callable that can extract the value when
    #     passed a HalClient::Representation of the item.
    #
    #   :coercion - proc to pass the extracted value through before
    #     storing it.
    def initialize(opts)
      @attr = opts.fetch(:attr) { fail ArgumentError, "attr is required" }
      @location = opts.fetch(:location) { "/#{attr}" }
      @fetcher = opts.fetch(:extraction_proc) { Hana::Pointer.new(location).method(:eval) }
      @value_coercion = opts.fetch(:coercion) { IDENTITY }

      fail(ArgumentError, ":coercion must respond to #call") unless
        value_coercion.respond_to? :call
    end

    # opts - named args
    #   :from - The HalRepresentation from which to extract attribute.
    #
    #   :to - The model that we are extracting
    #
    #   :context - The context(usually a HalInterpreter) in which to
    #     execute the extraction
    #
    # Returns any problems encountered.
    def extract(opts)
      from = opts.fetch(:from) { fail ArgumentError, "from is required" }
      to = opts.fetch(:to) { fail ArgumentError, "to is required" }
      context = opts.fetch(:context, self)

      raw_val = context.instance_exec from, &fetcher
      return [] if raw_val.nil?

      val = context.instance_exec raw_val, &value_coercion

      to.public_send "#{attr}=", val

      []
    rescue => err
      [err.message]
    end

    attr_reader :attr, :location

    protected
    attr_reader :fetcher, :value_coercion

    IDENTITY = ->(thing){ thing }
  end
end
