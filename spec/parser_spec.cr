require "./spec_helper"

private def it_parses(description, expected_value, bytes, file = __FILE__, line = __LINE__)
  slice = Slice(UInt8).new(bytes.buffer, bytes.length)
  it "parses #{description}", file, line do
    MessagePack.unpack(SliceIO(UInt8).new(slice)).should eq(expected_value)
  end
end

private def it_raises_on_parse(description, bytes, file = __FILE__, line = __LINE__)
  slice = Slice(UInt8).new(bytes.buffer, bytes.length)

  it "raises on parse #{description}", file, line do
    expect_raises MessagePack::ParseException do
      MessagePack.unpack(SliceIO(UInt8).new(slice))
    end
  end
end

describe "MessagePack::Parser" do
  it_parses("nil", nil, UInt8[0xC0u8])
  it_parses("false", false, UInt8[0xC2u8])
  it_parses("true", true, UInt8[0xC3u8])

  it_parses("zero", 0, UInt8[0x00])
  it_parses("fix num", 127, UInt8[0x7f])
  it_parses("small integers", 128, UInt8[0xcc, 0x80])
  it_parses("medium integers", 256, UInt8[0xcd, 0x01, 0x00])
  it_parses("large integers", 2**31 - 1, UInt8[0xce, 0x7f, 0xff, 0xff, 0xff])
  it_parses("huge integers", 2**64 - 1, UInt8[0xcf,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff])

  it_parses("-1", -1, UInt8[0xff])
  it_parses("-33", -33, UInt8[0xd0,0xdf])
  it_parses("-129", -129, UInt8[0xd1,0xff,0x7f])
  it_parses("-8444910", -8444910, UInt8[0xd2,0xff,0x7f,0x24,0x12])
  it_parses("-41957882392009710", -41957882392009710, UInt8[0xd3,0xff,0x6a,0xef,0x87,0x3c,0x7f,0x24,0x12])
  it_parses("negative integers", -1, UInt8[0xff])

  it_parses("1.0", 1.0, UInt8[0xcb,0x3f,0xf0,0x00,0x00,0x00,0x00,0x00,0x00])
  it_parses("small floats", 3.14, UInt8[203, 64, 9, 30, 184, 81, 235, 133, 31])
  it_parses("big floats", Math::PI * 1_000_000_000_000_000_000, UInt8[203, 67, 197, 204, 150, 239, 209, 25, 37])
  it_parses("negative floats", -2.1, UInt8[0xcb,0xc0,0x00,0xcc,0xcc,0xcc,0xcc,0xcc,0xcd])

  it_parses("strings", "hello world", UInt8[0xAB] + "hello world".bytes)
  it_parses("empty strings", "", UInt8[0xA0])
  it_parses("medium strings", "x" * 0xdd, UInt8[0xD9,0xDD] + ("x" * 0xDD).bytes)
  it_parses("big strings", "x" * 0xdddd, UInt8[0xDA, 0xDD, 0xDD] + ("x" * 0xdddd).bytes)
  it_parses("huge strings", "x" * 0x0000dddd, UInt8[0xDB, 0x00, 0x00, 0xDD,0xDD] + ("x" * 0x0000dddd).bytes)

  it_parses("medium binary", "\a" * 0x5, UInt8[0xc4,0x05] + ("\a" * 0x5).bytes)
  it_parses("big binary", "\a" * 0x100, UInt8[0xc5,0x01,0x00] + ("\a" * 0x100).bytes)
  it_parses("huge binary", "\a" * 0x10000, UInt8[0xc6, 0x00, 0x01, 0x00, 0x00] + ("\a" * 0x10000).bytes)

  it_parses("empty arrays", ([] of Type), UInt8[0x90])
  it_parses("small arrays", [1, 2], UInt8[0x92, 0x01, 0x02])
  it_parses("medium arrays", Array.new(0x111, false), UInt8[0xdc, 0x01, 0x11] + Array.new(0x111, 0xc2u8))
  it_parses("big arrays", Array.new(0x11111, false), UInt8[0xdd, 0x00, 0x01, 0x11, 0x11] + Array.new(0x11111, 0xc2_u8))
  it_parses("arrays with strings", ["hello", "world"], UInt8[0x92, 0xa5] + "hello".bytes + UInt8[0xa5] + "world".bytes)
  it_parses("arrays with mixed values", ["hello", "world", 42], UInt8[0x93, 0xa5]+ "hello".bytes + UInt8[0xa5] + "world*".bytes)
  it_parses("arrays of arrays", [[[[1, 2], 3], 4]], UInt8[0x91, 0x92, 0x92, 0x92, 0x01, 0x02, 0x03, 0x04])

  it_parses("empty hashes", ({} of Type => Type), UInt8[0x80])
  it_parses("small hashes", {"foo" => "bar"}, UInt8[0x81,0xa3] + "foo".bytes + UInt8[0xa3] + "bar".bytes)
  it_parses("medium hashes", {"foo" => "bar"}, UInt8[0xde, 0x00, 0x01, 0xa3] + "foo".bytes + UInt8[0xa3] + "bar".bytes)
  it_parses("big hashes", {"foo" => "bar"}, UInt8[0xdf, 0x00, 0x00, 0x00, 0x01, 0xa3] + "foo".bytes + UInt8[0xa3] + "bar".bytes)
  it_parses("hashes with mixed keys and values", {"foo" => "bar", 3 => "three", "four" => 4, "x" => ["y"], "a" => "b"}, UInt8[0x85,0xa3] + "foo".bytes + UInt8[0xa3] + "bar".bytes + UInt8[0x03,0xa5] + "three".bytes + UInt8[0xa4] + "four".bytes + UInt8[0x04, 0xa1] + "x".bytes + UInt8[0x91, 0xa1] + "y".bytes + UInt8[0xa1] + "a".bytes + UInt8[0xa1] + "b".bytes)
  it_parses("hashes of hashes", {({"x" => {"y" => "z"}}) => "s"}, UInt8[0x81, 0x81, 0xa1] + "x".bytes + UInt8[0x81, 0xa1] + "y".bytes + UInt8[0xa1] + "z".bytes + UInt8[0xa1] + "s".bytes)
  it_parses("hashes with nils", {"foo" => nil}, UInt8[0x81, 0xa3] + "foo".bytes + UInt8[0xc0])
end