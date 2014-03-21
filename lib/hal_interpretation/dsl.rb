module HalInterpretation
  module Dsl
    # Declare the class of models this interpreter builds.
    def item_class(klass)
      define_method(:item_class) do
        klass
      end
    end

    # Declare that an attribute should be extract from the HAL
    # document.
    #
    # attr_name - name of attribute on model to extract
    # opts - hash of named arguments to method
    #   :from - JSON path from which to get the value for 
    #     attribute. Default: "/#{attr_name}"
    def extract(attr_name, opts={})
      from = opts.fetch(:from) { "/#{attr_name}" }
      extractors << Extractor.new(attr: attr_name, location: from)
    end
  end
end