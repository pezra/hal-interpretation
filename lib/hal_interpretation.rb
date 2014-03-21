require "forwardable"
require "multi_json"
require "hal-client"

# Declarative interpretation of HAL documents into ActiveModel style
# objects.
module HalInterpretation

  # Returns array of models created from the HAL representation we are
  # interpreting.
  #
  # Raises InvalidRepresentationError if any of the models are invalid
  #   or the representation is not a HAL document.
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

  protected

  # opts
  #   :location - The json path of `a_representation` in the
  #     complete document
  def initialize(a_representation, opts)
    @repr = a_representation
    @location = opts.fetch(:location) { raise ArgumentError, "location is required" }
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
          ItemInterpreter.new(item_repr,
                              location: location + "_embedded/item/#{idx}/",
                              interpreter: self) }
        else
          [ItemInterpreter.new(repr, location: location, interpreter: self)]
        end
      end
  end

  # Back stop method to be overridden by individual interpreters.
  def item_class
    fail NotImplementedError, "interpreter classes must call `item_class <model class>` in the class defintion"
  end

  module ClassMethods
    # Returns new interpreter for the provided JSON document.
    #
    # Raises HalInterpretation::InvalidRepresentationError if the
    #   provided JSON document is not parseable
    def new_from_json(json)
      self.new HalClient::Representation.new(parsed_json: MultiJson.load(json)),
               location: "/"

    rescue MultiJson::ParseError => err
      fail InvalidRepresentationError, "Parse error: " + err.message
    end

    # internal stuff

    # Returns collection of attribute extractors.
    def extractors
      @extractors ||= []
    end

    # Returns the attribute extractor for the specified attribute.
    def extractor_for(attr_name)
      extractors.find {|it| it.attr == attr_name }
    end
  end


  def self.included(klass)
    klass.extend ClassMethods
    klass.extend Dsl
  end


  autoload :Dsl, "hal_interpretation/dsl"
  autoload :ItemInterpreter, "hal_interpretation/item_interpreter"
  autoload :Extractor, "hal_interpretation/extractor"
  autoload :Error, "hal_interpretation/errors"
  autoload :InvalidRepresentationError, "hal_interpretation/errors"

end

require "hal_interpretation/version"
