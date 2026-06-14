///|
test "end-to-end: parse proto and verify structure" {
  let input =
    #|syntax = "proto3";
    #|package test;
    #|
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|  repeated string tags = 3;
    #|  Address address = 4;
    #|}
    #|
    #|message Address {
    #|  string street = 1;
    #|  string city = 2;
    #|  int32 zip = 3;
    #|}
    #|
    #|enum Status {
    #|  UNKNOWN = 0;
    #|  ACTIVE = 1;
    #|  INACTIVE = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.syntax, "proto3")
  assert_eq(file.package_name, "test")
  assert_eq(file.messages.length(), 2)
  assert_eq(file.enums.length(), 1)
  assert_eq(file.messages[0].fields.length(), 4)
  assert_true(file.messages[0].fields[2].label == Repeated)
  assert_true(file.messages[0].fields[3].field_type == Message("Address"))
}

///|
test "end-to-end: codegen produces valid structure" {
  let input =
    #|syntax = "proto3";
    #|message Simple {
    #|  int32 id = 1;
    #|  string value = 2;
    #|}
  let file = @proto_parser.parse(input)
  let code = @codegen.generate(file)
  assert_true(code.contains("pub(all) struct Simple"))
  assert_true(code.contains("id : Int"))
  assert_true(code.contains("value : String"))
  assert_true(code.contains("Simple::new()"))
  assert_true(code.contains("Simple::encode"))
  assert_true(code.contains("Simple::decode"))
  assert_true(code.contains("write_int32(1"))
  assert_true(code.contains("write_string(2"))
  assert_true(code.contains("read_int32()"))
  assert_true(code.contains("read_string()"))
}

///|
test "wire format: known protobuf binary compatibility" {
  // Protobuf encoding of: { field 1 (string) = "testing" }
  // tag: (1 << 3) | 2 = 0x0A, length: 7, data: "testing" (UTF-8)
  let enc = @wire.Encoder::new()
  enc.write_string(1, "testing")
  let data = enc.finish()
  assert_eq(data[0], b'\x0A')
  assert_eq(data[1], b'\x07')
  assert_eq(data[2], b'\x74') // 't'
  assert_eq(data[3], b'\x65') // 'e'
  assert_eq(data[4], b'\x73') // 's'
  assert_eq(data[5], b'\x74') // 't'
  assert_eq(data[6], b'\x69') // 'i'
  assert_eq(data[7], b'\x6E') // 'n'
  assert_eq(data[8], b'\x67') // 'g'
}

///|
test "wire format: varint 150 encoding matches spec" {
  // From protobuf docs: 150 encodes as 0x96 0x01
  let enc = @wire.Encoder::new()
  enc.write_int32(1, 150)
  let data = enc.finish()
  assert_eq(data[0], b'\x08') // tag: (1 << 3) | 0 = 8
  assert_eq(data[1], b'\x96') // 150 varint byte 1
  assert_eq(data[2], b'\x01') // 150 varint byte 2
}

///|
test "wire format: multiple field roundtrip" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Bob")
  enc.write_int32(2, 25)
  enc.write_bool(3, true)
  enc.write_double(4, 1.5)
  enc.write_sint32(5, -42)
  enc.write_fixed64(6, 0xCAFEBABEUL)
  let data = enc.finish()
  let dec = @wire.Decoder::new(data)
  let mut f1 = ""
  let mut f2 = 0
  let mut f3 = false
  let mut f4 = 0.0
  let mut f5 = 0
  let mut f6 : UInt64 = 0UL
  while !dec.is_at_end() {
    let tag = dec.read_tag()
    match tag.field_number {
      1 => f1 = dec.read_string()
      2 => f2 = dec.read_int32()
      3 => f3 = dec.read_bool()
      4 => f4 = dec.read_double()
      5 => f5 = dec.read_sint32()
      6 => f6 = dec.read_fixed64()
      _ => dec.skip_field(tag.wire_type)
    }
  }
  assert_eq(f1, "Bob")
  assert_eq(f2, 25)
  assert_eq(f3, true)
  assert_eq(f4, 1.5)
  assert_eq(f5, -42)
  assert_eq(f6, 0xCAFEBABEUL)
}

///|
test "wire format: nested message binary structure" {
  let enc = @wire.Encoder::new()
  enc.write_message(1, sub => {
    sub.write_int32(1, 100)
    sub.write_string(2, "nested")
  })
  let data = enc.finish()
  // First byte is tag: (1 << 3) | 2 = 0x0A (field 1, length-delimited)
  assert_eq(data[0], b'\x0A')
  // Second byte is length of nested message
  let nested_len = data[1]
  // Decode to verify
  let dec = @wire.Decoder::new(data)
  let _ = dec.read_tag()
  let mut inner_id = 0
  let mut inner_name = ""
  dec.read_message(sub_dec => {
    while !sub_dec.is_at_end() {
      let tag = sub_dec.read_tag()
      match tag.field_number {
        1 => inner_id = sub_dec.read_int32()
        2 => inner_name = sub_dec.read_string()
        _ => sub_dec.skip_field(tag.wire_type)
      }
    }
  })
  assert_eq(inner_id, 100)
  assert_eq(inner_name, "nested")
  ignore(nested_len)
}

///|
test "wire format: forward compatibility (skip unknown fields)" {
  // Simulate receiving data with extra fields the decoder doesn't know about
  let enc = @wire.Encoder::new()
  enc.write_string(1, "known")
  enc.write_int64(100, 9999L) // unknown varint field
  enc.write_fixed32(101, 0xFFU) // unknown fixed32
  enc.write_string(102, "unknown") // unknown length-delimited
  enc.write_fixed64(103, 0xAAUL) // unknown fixed64
  enc.write_int32(2, 42)
  let dec = @wire.Decoder::new(enc.finish())
  let mut f1 = ""
  let mut f2 = 0
  while !dec.is_at_end() {
    let tag = dec.read_tag()
    match tag.field_number {
      1 => f1 = dec.read_string()
      2 => f2 = dec.read_int32()
      _ => dec.skip_field(tag.wire_type)
    }
  }
  assert_eq(f1, "known")
  assert_eq(f2, 42)
}

///|
test "full pipeline: parse, generate, verify code structure" {
  let proto =
    #|syntax = "proto3";
    #|package myapp;
    #|
    #|enum Color {
    #|  RED = 0;
    #|  GREEN = 1;
    #|  BLUE = 2;
    #|}
    #|
    #|message Point {
    #|  double x = 1;
    #|  double y = 2;
    #|  optional string label = 3;
    #|}
  let file = @proto_parser.parse(proto)
  let code = @codegen.generate(file)
  assert_true(code.contains("pub(all) enum Color"))
  assert_true(code.contains("Color::to_int"))
  assert_true(code.contains("Color::from_int"))
  assert_true(code.contains("pub(all) struct Point"))
  assert_true(code.contains("x : Double"))
  assert_true(code.contains("y : Double"))
  assert_true(code.contains("label : String"))
  assert_true(code.contains("write_double"))
  assert_true(code.contains("read_double"))
}
