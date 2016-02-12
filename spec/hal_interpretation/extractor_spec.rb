require_relative "../spec_helper"

describe HalInterpretation::Extractor do
  describe "creation" do
    specify { expect{described_class.new(attr: "first_name", location: "/firstName")}
      .not_to raise_error }
    specify { expect{described_class.new(attr: "first_name", with: ->(hal_repr){ "bob" })}
      .not_to raise_error }
    specify { expect{described_class.new(attr: "first_name", location: "/firstName",
                                         coercion: ->(){ 42 })}
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

  context "context dependent lambda based" do
    subject(:extractor) { described_class
        .new(attr: "seq", location: "/seq", extraction_proc:
             ->(hal_repr) { self.count_so_far }) }

    specify { expect{
        extractor.extract(from: source, to: target, context: interpreter)
      }.not_to raise_error }


    context "after extraction" do
      before do extractor.extract(from: source, to: target, context: interpreter) end

      specify { expect(target.seq).to eq 42 }
    end

    let(:interpreter) { double(:interpreter, count_so_far: 42) }
  end

  context "coercion" do
    subject(:extractor) { described_class.new(attr: "bday",
                                              coercion: ->(val){ Time.parse(val) } ) }
    before do extractor.extract(from: source, to: target) end

    specify { expect(target.bday).to eq Time.utc(2013,10,10,12,13,14) }
  end

  context "basic attr" do
    subject(:extractor) { described_class.new(attr: "age") }

    before do extractor.extract(from: source, to: target) end

    specify { expect(target.age).to eq 1 }
  end

  context "boolean attr true" do
    subject(:extractor) { described_class.new(attr: "likes_chocolate",
                                              location: "/likesChocolate") }

    before do extractor.extract(from: source, to: target) end

    specify { expect(target.likes_chocolate).to eq true }
  end

  context "boolean attr false" do
    subject(:extractor) { described_class.new(attr: "likes_anchovies",
                                              location: "/likesAnchovies") }

    before do extractor.extract(from: source, to: target) end

    specify { expect(target.likes_anchovies).to eq false }
  end

  context "missing attr" do
    subject(:extractor) { described_class.new(attr: "seq") }

    before do extractor.extract(from: source, to: target) end

    specify { expect(target.seq).to be_nil }
  end


  let(:target) { Struct.new(:first_name,
                            :bday,
                            :parent,
                            :seq,
                            :age,
                            :likes_chocolate,
                            :likes_anchovies).new }

  let(:source) { HalClient::Representation.new(parsed_json: {
                                                 "age" => 1,
                                                 "firstName" => "Alice",
                                                 "bday" => "2013-10-10T12:13:14Z",
                                                 "likesChocolate" => true,
                                                 "likesAnchovies" => false,
                                                 "_links" => {
                                                   "up" => { "href" => "http://foo" }}}) }
end
