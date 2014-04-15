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
    #
    # opts - hash of named arguments to method
    #
    #   :from - JSON path from which to get the value for
    #     attribute. Default: "/#{attr_name}".
    #
    #   :with - Callable that can extract the value when
    #     passed a HalClient::Representation of the item.
    def extract(attr_name, opts={})
      extractor_opts = {
        attr: attr_name,
        location: opts.fetch(:from) { "/#{attr_name}" }
      }
      extractor_opts[:extraction_proc] = opts.fetch(:with) if opts.key? :with

      extractors << Extractor.new(extractor_opts)
    end
  end
end