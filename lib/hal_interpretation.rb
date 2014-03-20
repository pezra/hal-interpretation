require "forwardable"
require "hana"
require "multi_json"
require "hal-client"

InvalidRepresentationError = Class.new(StandardError)

module HalInterpretation
  module DSL
    def item_class(klass)
      define_method(:item_class) do
        klass
      end
    end

    def extract(attr_name,from: "/#{attr_name}")
      extractors << Extractor.new(attr: attr_name, location: from)
    end
  end

  module ClassMethods
    def new_from_json(json)
      self.new HalClient::Representation.new(parsed_json: MultiJson.load(json)),
               location: "/"

    rescue MultiJson::ParseError => err
      fail InvalidRepresentationError, "Parse error: " + err.message
    end

    def extractors
      @extractors ||= []
    end

    def extractor_for(attr_name)
      extractors.find {|it| it.attr == attr_name }
    end
  end

  def self.included(klass)
    klass.extend ClassMethods
    klass.extend DSL
  end

  def items
    (fail InvalidRepresentationError.new(problems)) if problems.any?

    @observations ||= interpreters.flat_map(&:items)
  end

  # Returns array of problems messages, or empty array if there are
  # none. This will do a complete interpretation of the representation
  # if it has not already been done.
  def problems
    @problems ||= interpreters.flat_map(&:problems)
  end

  extend Forwardable
  def_delegators "self.class", :extractors, :extractor_for

  def extractor_for(*args)
    self.class.extractor_for(*args)
  end



  protected

  def initialize(a_representation, location:)
    @repr = a_representation
    @location = location
  end

  attr_reader :repr, :location

  def interpreters
    @interpreters ||=
      begin
        if repr.has_related? 'item'
          repr
            .related('item')
            .each_with_index
            .map{ |item_repr, idx|
          Single.new(item_repr,
                     location: location + "_embedded/item/#{idx}/",
                     interpreter: self) }
        else
          [Single.new(repr, location: location, interpreter: self)]
        end
      end
  end

  def item_class
    fail NotImplementedError, "item_class must be defined by each interpreter class"
  end


  class Single
    def initialize(a_representation, location:, interpreter:)
      @repr = a_representation
      @location = location
      @problems = []
      @interpreter = interpreter
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

    def_delegators :interpreter, :extractors, :extractor_for, :item_class

    attr_reader :repr, :location, :interpreter

    def done?
      !@items.nil? || @problems.any?
    end

    def interpret
      new_item = item_class.new do |it|
        e = extractors
        e.each do |an_extractor|
          @problems += an_extractor.extract(from: repr, to: it)
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
        @problems << "#{json_path_for attr} #{msg}"
      end
    end

    def json_path_for(attr)
      json_pointer_join(location, extractor_for(attr).location)
    end

    def json_pointer_join(head, tail)
      head = head[0..-2] if head.end_with?("/")
      tail = tail[1..-1] if tail.start_with?("/")

      head + "/" + tail
    end
  end

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

require "hal_interpretation/version"
