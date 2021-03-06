# encoding: utf-8

require "spec_helper"

describe TOML::Transform do
  let(:xform) { TOML::Transform.new }

  context "values" do
    it "transforms an integer value" do
      expect(xform.apply(:integer => "1")).to eq(1)
    end

    it "transforms a float" do
      expect(xform.apply(:float => "0.123")).to eq(0.123)
    end

    it "transforms a boolean" do
      expect(xform.apply(:boolean => "true")).to eq(true)
      expect(xform.apply(:boolean => "false")).to eq(false)
    end

    it "transforms a datetime" do
      expect(xform.apply(:datetime => "1979-05-27T07:32:00Z")).to eq(
        Time.parse("1979-05-27T07:32:00Z"))
    end

    it "transforms a string" do
      expect(xform.apply(:string => "a string")).to eq("a string")
    end

    it "unescapes special characters in captured strings" do
      expect(xform.apply(:string => "\\b")).to eq("\b")
      expect(xform.apply(:string => "\\t")).to eq("\t")
      expect(xform.apply(:string => "\\n")).to eq("\n")
      expect(xform.apply(:string => "\\f")).to eq("\f")
      expect(xform.apply(:string => "\\r")).to eq("\r")
      expect(xform.apply(:string => "\\\"")).to eq("\"")
      expect(xform.apply(:string => "\\/")).to eq("/")
      expect(xform.apply(:string => "\\\\")).to eq("\\")
    end

    it "unescapes unicode sequences in captured strings" do
      expect(xform.apply(:string => "jos\u00E9\u000A")).to eq("josé\n")
    end
  end

  context "arrays" do
    it "transforms an array of integers" do
      input = { :array => [ {:integer => "1"}, {:integer => "2"} ] }
      expect( xform.apply(input) ).to eq([1,2])
    end

    it "transforms an empty array" do
      input= {:array => "[]"}
      expect( xform.apply(input) ).to eq([])
    end

    it "transforms nested arrays" do
      input = {
        :array => [
          { :array => [ {:integer => "1"}, {:integer => "2"} ] },
          { :array => [ {:float => "0.1"}, {:float => "0.2"} ] }
        ]
      }
      expect( xform.apply(input) ).to eq([[1,2], [0.1,0.2]])
    end
  end

  context "key/value assignment" do
    it "converts a key/value pair into a pairs" do
      input = {:key => "a key", :value => "a value"}
      expect( xform.apply(input) ).to eq("a key" => "a value")
    end

    it "converts a key/value pair with an array value" do
      input = {:key => "a key", :value => [[1,2],[3,4]]}
      expect( xform.apply(input) ).to eq("a key" => [[1,2],[3,4]])
    end

  end

  context "a list of global assignments" do
    it "converts a list of global assignments into a hash" do
      input = {:assignments =>
               [{:key => "c", :value => {:integer => "3"}},
                {:key => "d", :value => {:integer => "4"}}]}
      expect(xform.apply(input)).to eq("c" => 3, "d" => 4)
    end

    it "converts an empty (comments-only) assignments list" do
      input = {:assignments => "\n#comment"}
      expect(xform.apply(input)).to eq({})
    end

    it "converts an array assignment" do
      input = {:assignments => {:key => "a", :value => [1, 2]}}
      expect( xform.apply(input) ).to eq( "a" => [1,2] )
    end
  end

  context "a key group" do
    it "converts a group name and assignments into a hash" do
      input = TOML::Parser.new.parse("[group]\nc=1\nd=2")
      expect(xform.apply(input)).to eq(
        "group" => {"c" => 1, "d" => 2}
      )
    end

    it "converts a complex group name and values into a nested hash" do
      input = TOML::Parser.new.parse("[foo.bar]\nc=1\nd=2")
      expect(xform.apply(input)).to eq(
        "foo" => {"bar" => {"c" => 1, "d" => 2}}
      )
    end

    it "converts an empty key group (comments-only) into a hash" do
      input = TOML::Parser.new.parse("[foo.bar]\n#comment")
      expect(xform.apply(input)).to eq(
        "foo" => {"bar" => {}}
      )
    end
  end

  it "merges subsequent key groups into a single group" do
    input = TOML::Parser.new.parse(
      "[foo.bar]
       a = 1
       b = 2
       [foo.baz]
       c = 3
       d = 4")
    expect(xform.apply(input)).to eq(
      "foo" => {
        "bar" => { "a" => 1, "b" => 2 },
        "baz" => { "c" => 3, "d" => 4 }
      }
    )
  end

  it "converts a TOML document with just an empty key group" do
    input = TOML::Parser.new.parse("[key.group]")
    expect(xform.apply(input)).to eq("key" => {"group" => {}})
  end

  it "converts a simple TOML doc into a hash" do
    input = TOML::Parser.new.parse(fixture("simple.toml"))
    expect(xform.apply(input)).to eq(
      "title" => "global title",
      "group1" => {"a" => 1, "b" => 2},
      "group2" => {"c" => [3, 4]}
    )
  end

  it "converts a full TOML doc into a hash" do
    input = TOML::Parser.new.parse(fixture("example.toml"))
    output = YAML.load(fixture("example.yaml"))
    expect(xform.apply(input)).to eq(output)
  end

  it "converts a hard TOML doc into a hash" do
    input = TOML::Parser.new.parse(fixture("hard_example.toml"))
    expected = YAML.load(fixture("hard_example.yaml"))
    output = xform.apply input

    expected["the"].keys.each do |k|
      expect(output["the"][k]).to eq(expected["the"][k])
    end
  end

  it "raises an error when attempting to reassign a key" do
    input = TOML::Parser.new.parse(fixture("reassign_key.toml"))
    expect { xform.apply(input) }.to raise_error(
      TOML::TransformError, /reassign.*line 4 column 1/)
  end

  it "raises an error when attempting to reassign a value" do
    input = TOML::Parser.new.parse(fixture("reassign_value.toml"))
    expect { xform.apply(input) }.to raise_error(
      TOML::TransformError, /reassign.*line 3 column 2/)
  end

end

