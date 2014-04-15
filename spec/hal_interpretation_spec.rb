require_relative "spec_helper"
require "active_support"
require "active_model"
require "rspec/collection_matchers"

describe HalInterpretation do
  subject(:interpreter_class) {
    test_item_class = self.test_item_class
    Class.new do
      include HalInterpretation
      item_class test_item_class
      extract :name
      extract :latitude, from: "/geo/latitude"
      extract :up, with: ->(hal_repr){hal_repr.related_hrefs("up").first}, from: "/_links/up"
      extract :bday, coercion: ->(val){ Time.parse(val) }
    end }

  context "valid single item" do
    let(:json_doc) { <<-JSON }
      { "name": "foo"
        ,"bday": "2013-12-11T10:09:08Z"
        ,"geo": {
          "latitude": 39.1
        }
        ,"_links": {
          "up": {"href": "/foo"}
        }
      }
    JSON

    specify { expect(interpreter.items).to have(1).item }
    specify { expect(interpreter.items.first.name).to eq "foo" }
    specify { expect(interpreter.items.first.latitude).to eq 39.1 }
    specify { expect(interpreter.items.first.up).to eq "/foo" }
    specify { expect(interpreter.items.first.bday).to eq Time.utc(2013,12,11,10,9,8) }
    specify { expect(interpreter.problems).to be_empty }
  end

  context "valid collection" do
    let(:json_doc) { <<-JSON }
      { "_embedded": {
           "item": [{ "name": "foo"
                      ,"bday": "2013-12-11T10:09:08Z"
                      ,"geo": {
                        "latitude": 39.1
                      }
                      ,"_links": { "up": {"href": "/foo"} }
                    }
                    ,{ "name": "bar"
                      ,"bday": "2013-12-11T10:09:08Z"
                      ,"geo": {
                        "latitude": 39.2
                      }
                      ,"_links": { "up": {"href": "/bar"} }
                    }]
        }
      }
    JSON

    specify { expect(interpreter.problems).to be_empty }
    specify { expect(interpreter.items).to have(2).items }
    specify { expect(interpreter.items).to include item_named "foo" }
    specify { expect(interpreter.items).to include item_named "bar" }

    matcher :item_named do |expected_name|
      match do |obj|
        obj.name == expected_name
      end
    end
  end

  context "invalid attributes" do
    let(:json_doc) { <<-JSON }
      { "geo": {
          "latitude": "hello"
        }
        ,"bday": "yesterday"
      }
    JSON

    specify { expect{interpreter.items}
        .to raise_exception HalInterpretation::InvalidRepresentationError }
    context "raised error" do
      subject(:error) { interpreter.items rescue $! }

      specify { expect(error.problems)
          .to include matching matching(%r(/geo/latitude\b)).and(match(/\binvalid value\b/i)) }
      specify { expect(error.problems)
          .to include matching(%r(/name\b)).and(match(/\bblank\b/i))  }
    end
    specify { expect(interpreter.problems)
        .to include matching(%r(/name\b)).and(match(/\bblank\b/i))  }
    specify { expect(interpreter.problems)
        .to include matching(%r(/geo/latitude\b)).and(match(/\binvalid value\b/i))  }
    specify { expect(interpreter.problems)
        .to include matching(%r(/bday\b)).and(match(/\bno time\b/i))  }
  end

  context "collection w/ invalid attributes" do
    let(:json_doc) { <<-JSON }
      { "_embedded": {
           "item": [{ "geo": {
                        "latitude": "hello"
                       }
                     }]
        }
      }
    JSON

    specify { expect{interpreter.items}
        .to raise_exception HalInterpretation::InvalidRepresentationError }
    specify { expect(interpreter.problems)
        .to include matching(%r(/_embedded/item/0/name\b)).and(match(/\bblank\b/i))  }
    specify { expect(interpreter.problems)
        .to include matching(%r(/_embedded/item/0/geo/latitude\b))
                      .and(match(/\binvalid value\b/i))  }

  end

  context "missing compound member" do
    let(:json_doc) { <<-JSON }
      { "name": "nowhere" }
    JSON

    specify { expect{interpreter.items}
        .to raise_exception HalInterpretation::InvalidRepresentationError}
    specify { expect(interpreter.problems)
        .to include matching(%r(/geo/latitude\b)).and(match(/\bblank\b/i))  }
  end


  context "non-json doc" do
    let(:non_json_doc) { "what's json" }

    specify { expect{interpreter_class.new_from_json(non_json_doc)}
        .to raise_exception HalInterpretation::InvalidRepresentationError, /\bparse\b/i }
  end

  let(:interpreter) { interpreter_class.new_from_json(json_doc) }

  let(:test_item_class) { Class.new do
      include ActiveModel::Validations

      attr_accessor :name, :latitude, :up, :bday

      def initialize
        yield self
      end

      def latitude=(lat)
        @latitude = if !lat.nil?
                      Float(lat)
                    else
                      nil
                    end
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, "temp")
      end

      validates :name, presence: true
      validates :latitude, presence: true
    end }
end
