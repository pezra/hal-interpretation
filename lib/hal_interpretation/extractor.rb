require 'hana'

module HalInterpretation
  class Extractor
    def initialize(attr:, location: "/#{attr}")
      @attr = attr
      @location = location
      @pointer = Hana::Pointer.new(location)
    end

    def extract(from:, to:)
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