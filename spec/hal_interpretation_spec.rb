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
      extract :bday, coercion: ->(val){ Time.parse(val) }
      extract :seq, with: ->(_) { next_seq_num }
      extract_link  :up
      extract_links :friend_ids, rel: "http://xmlns.com/foaf/0.1/knows",
                    coercion: ->(urls) { urls.map{|u| u.split("/").last } }
      extract_link :archives_url_tmpl, rel: "archives"
      extract_repr :profile, rel: "http://xmlns.com/foaf/0.1/Person"
      extract_reprs :cohorts, rel: "http://xmlns.com/foaf/0.1/knows"

      def initialize(*args)
        @cur_seq_num = 0
        super
      end

      def next_seq_num
        @cur_seq_num += 1
      end
    end
  }

  let(:interpreter) { interpreter_class.new_from_json(json_doc) }

  specify { expect(interpreter.only_update(:anything)).to eq interpreter }

  context "valid single item" do
    let(:json_doc) { <<-JSON }
      { "name": "foo"
        ,"bday": "2013-12-11T10:09:08Z"
        ,"geo": {
          "latitude": 39.1
        }
        ,"_links": {
          "up": { "href": "/foo" },
          "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/foo" },
          "http://xmlns.com/foaf/0.1/knows": [
            { "href": "http://example.com/bob" },
            { "href": "http://example.com/alice" }
          ],
          "archives": {
            "href": "http://example.com/old{?since,until}",
            "templated": true
          }
        }
      }
    JSON

    specify { expect(interpreter.items).to have(1).item }
    specify { expect(interpreter.item).to be interpreter.items.first }
    specify { expect(interpreter.item.name).to eq "foo" }
    specify { expect(interpreter.item.latitude).to eq 39.1 }
    specify { expect(interpreter.item.up).to eq "/foo" }
    specify { expect(interpreter.item.bday).to eq Time.utc(2013,12,11,10,9,8) }
    specify { expect(interpreter.item.seq).to eq 1 }
    specify { expect(interpreter.item.profile).to be_kind_of HalClient::Representation }
    specify { expect(interpreter.item.cohorts).to be_kind_of HalClient::RepresentationSet }
    specify { expect(interpreter.item.friend_ids).to eq ["bob", "alice"] }
    specify { expect(interpreter.item.archives_url_tmpl)
              .to eq "http://example.com/old{?since,until}" }

    specify { expect(interpreter.problems).to be_empty }

    specify { expect(interpreter.collection?).to be false }

    context "for update" do
      let(:existing) { test_item_class.new do |it|
                         it.name = "foo"
                         it.latitude = 40
                       end }

      before do interpreter.only_update(existing) end

      specify { expect(interpreter.items).to have(1).item }
      specify { expect(interpreter.item).to be interpreter.items.first }
      specify { expect(interpreter.item).to eq existing }
      specify { expect(interpreter.item.name).to eq "foo" }
      specify { expect(interpreter.item.latitude).to eq 39.1 }
      specify { expect(interpreter.item.bday).to eq Time.utc(2013,12,11,10,9,8) }
    end

    context "with embedded links" do
      let(:json_doc) { <<-JSON }
          { "name": "foo"
            ,"bday": "2013-12-11T10:09:08Z"
            ,"geo": {
              "latitude": 39.1
            }
            ,"_embedded": {
              "up": { "_links": { "self": { "href": "/foo" } } },
              "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/foo" },
              "http://xmlns.com/foaf/0.1/knows": [
                { "_links": { "self":{ "href": "http://example.com/bob" } } },
                { "_links": { "self":{ "href": "http://example.com/alice" } } }
              ]
            }
          }
        JSON

      specify { expect(interpreter.item.up).to eq "/foo" }
      specify { expect(interpreter.item.friend_ids).to eq ["bob", "alice"] }
      specify { expect(interpreter.item.profile).to be_kind_of HalClient::Representation }
      specify { expect(interpreter.item.cohorts).to be_kind_of HalClient::RepresentationSet }
    end
  end

  context "valid collection" do
    let(:json_doc) { <<-JSON }
      { "_embedded": {
           "item": [{ "name": "foo"
                      ,"bday": "2013-12-11T10:09:08Z"
                      ,"geo": {
                        "latitude": 39.1
                      }
                      ,"_links": {
                        "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/foo" },
                        "up": {"href": "/foo"}
                      }
                    }
                    ,{ "name": "bar"
                      ,"bday": "2013-12-11T10:09:08Z"
                      ,"geo": {
                        "latitude": 39.2
                      }
                      ,"_links": {
                         "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/bar" },
                         "up": {"href": "/bar"}
                      }
                    }]
        }
      }
    JSON

    specify { expect(interpreter.problems).to be_empty }
    specify { expect(interpreter.items).to have(2).items }
    specify { expect(interpreter.items).to include item_named "foo" }
    specify { expect(interpreter.items).to include item_named "bar" }
    specify { expect(interpreter.items[0].seq).to eq 1 }
    specify { expect(interpreter.items[1].seq).to eq 2 }
    specify { expect(interpreter.items[0].profile).to be_kind_of HalClient::Representation }
    specify { expect(interpreter.items[1].profile).to be_kind_of HalClient::Representation }

    specify { expect{interpreter.item}
              .to raise_error HalInterpretation::InvalidRepresentationError }

    specify { expect(interpreter.collection?).to be true }

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

    before do
      test_item_class.class_eval do
        validates :up, presence: true
        validates :friend_ids, presence: { message: "only popular people allowed" }
      end
    end

    specify { expect{interpreter.items}
        .to raise_exception HalInterpretation::InvalidRepresentationError }
    context "raised error" do
      subject(:error) { interpreter.items rescue $! }

      specify { expect(error.problems)
          .to include matching(%r(/geo/latitude\b)).and(match(/\binvalid value\b/i)) }
      specify { expect(error.problems)
          .to include matching(%r(/name\b)).and(match(/\bblank\b/i))  }
    end

    specify { expect(interpreter.problems)
        .to include matching(%r(/name\b)).and(match(/\bblank\b/i))  }
    specify { expect(interpreter.problems)
        .to include matching(%r(/geo/latitude\b)).and(match(/\binvalid value\b/i))  }
    specify { expect(interpreter.problems)
        .to include matching(%r(/bday\b)).and(match(/\bno time\b/i))  }
    specify { expect(interpreter.problems)
              .to include matching(%r(/_links/up\b)).and(match(/\bblank\b/i)) }
    specify { expect(interpreter.problems)
              .to include matching(%r(/_links/http:~1~1xmlns.com~1foaf~10.1~1knows\b))
                           .and(match(/\bpopular\b/i)) }
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

  context "missing non-required member" do
    let(:json_doc) { <<-JSON }
      { "name": "nowhere"
        ,"geo": {
          "latitude": 13.12
        }
        ,"_links": {
          "up": { "href": "http://example.com/" }
        }
      }
    JSON

    specify { expect(interpreter.problems).to be_empty }
  end

  context "validation failure on unmapped attr" do
    let(:json_doc) { <<-JSON }
      { "name": "nowhere"
        ,"geo": {
          "latitude": 13.12
        }
        ,"_links": {
          "up": { "href": "http://example.com/" }
        }
      }
    JSON

    before do
      test_item_class.class_eval "validates :hair, presence: true"
    end

    specify { expect{interpreter.items}
        .to raise_exception HalInterpretation::InvalidRepresentationError}
    specify { expect(interpreter.problems)
        .to include matching(/hair/).and(match(/\bblank\b/i))  }
  end

  context "non-json doc" do
    let(:non_json_doc) { "what's json" }

    specify { expect{interpreter_class.new_from_json(non_json_doc)}
        .to raise_exception HalInterpretation::InvalidRepresentationError, /\bparse\b/i }
  end

  # default
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

  let(:test_item_class) { Class.new do
      include ActiveModel::Validations

      attr_accessor :name, :latitude, :up, :bday, :seq, :hair, :friend_ids,
                    :archives_url_tmpl, :profile, :cohorts

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
