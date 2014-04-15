require_relative "../spec_helper"

describe HalInterpretation::Extractor do
  describe "creation" do
    specify { expect{described_class.new(attr: "first_name", location: "/firstName")}
      .not_to raise_error }
    specify { expect{described_class.new(attr: "first_name", with: ->(hal_repr){ "bob" })}
      .not_to raise_error }
  end

  context "location based" do
    subject(:extractor) { described_class.new(attr: "first_name", location: "/firstName") }

    specify { expect{extractor.extract(from: source, to: target)}.not_to raise_error }

    context "after extraction" do
      before do extractor.extract(from: source, to: target) end

      specify { expect(target.first_name).to eq "Alice" }
    end
  end

  context "lambda based" do
    subject(:extractor) { described_class
        .new(attr: "parent", location: "/_links/up",
             extraction_proc: ->(hal_repr) {hal_repr.related_hrefs("up").first}) }

    specify { expect{extractor.extract(from: source, to: target)}.not_to raise_error }

    context "after extraction" do
      before do extractor.extract(from: source, to: target) end

      specify { expect(target.parent).to eq "http://foo" }
    end
  end

  let(:target) { Struct.new(:first_name, :parent).new }
  let(:source) { HalClient::Representation.new(parsed_json: {
                                                 "firstName" => "Alice",
                                                 "_links" => {
                                                   "up" => { "href" => "http://foo" }}}) }
end
