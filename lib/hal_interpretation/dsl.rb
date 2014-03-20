module HalInterpretation
  module Dsl
    def item_class(klass)
      define_method(:item_class) do
        klass
      end
    end

    def extract(attr_name,from: "/#{attr_name}")
      extractors << Extractor.new(attr: attr_name, location: from)
    end
  end
end