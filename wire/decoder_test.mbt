///|
test "roundtrip int32" {
  let enc = @wire.Encoder::new()
  enc.write_int32(1, 150)
  let dec = @wire.Decoder::new(enc.finish())
  let tag = dec.read_tag()
  assert_true(tag.field_number == 1)
  assert_true(tag.wire_type == Varint)
  assert_eq(dec.read_int32(), 150)
  assert_true(dec.is_at_end())
}

///|
test "roundtrip int64" {
  let enc = @wire.Encoder::new()
  enc.write_int64(1, 123456789012345L)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_int64(), 123456789012345L)
}

///|
test "roundtrip uint32" {
  let enc = @wire.Encoder::new()
  enc.write_uint32(1, 4294967295U)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_uint32(), 4294967295U)
}

///|
test "roundtrip sint32 negative" {
  let enc = @wire.Encoder::new()
  enc.write_sint32(1, -100)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_sint32(), -100)
}

///|
test "roundtrip bool" {
  let enc = @wire.Encoder::new()
  enc.write_bool(1, true)
  enc.write_bool(2, false)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_bool(), true)
  let _ = dec.read_tag()
  assert_eq(dec.read_bool(), false)
}

///|
test "roundtrip string" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "hello world")
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_string(), "hello world")
}

///|
test "roundtrip string unicode" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "你好世界")
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_string(), "你好世界")
}

///|
test "roundtrip bytes" {
  let enc = @wire.Encoder::new()
  enc.write_bytes(1, [b'\x01', b'\x02', b'\x03'])
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let result = dec.read_bytes()
  assert_eq(result.length(), 3)
  assert_eq(result[0], b'\x01')
  assert_eq(result[2], b'\x03')
}

///|
test "roundtrip float" {
  let enc = @wire.Encoder::new()
  enc.write_float(1, 3.14)
  let dec = @wire.Decoder::new(enc.finish())
  let tag = dec.read_tag()
  assert_true(tag.wire_type == Fixed32)
  let v = dec.read_float()
  assert_true((v - 3.14).abs() < 0.001)
}

///|
test "roundtrip double" {
  let enc = @wire.Encoder::new()
  enc.write_double(1, 3.141592653589793)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_double(), 3.141592653589793)
}

///|
test "roundtrip fixed32" {
  let enc = @wire.Encoder::new()
  enc.write_fixed32(1, 0xDEADBEEFU)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_fixed32(), 0xDEADBEEFU)
}

///|
test "roundtrip fixed64" {
  let enc = @wire.Encoder::new()
  enc.write_fixed64(1, 0xDEADBEEFCAFEBABEUL)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_fixed64(), 0xDEADBEEFCAFEBABEUL)
}

///|
test "roundtrip nested message" {
  let enc = @wire.Encoder::new()
  enc.write_message(1, fn(sub) { sub.write_int32(1, 42) })
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let mut inner_value = 0
  dec.read_message((sub_dec) => {
    let _ = sub_dec.read_tag()
    inner_value = sub_dec.read_int32()
  })
  assert_eq(inner_value, 42)
}

///|
test "roundtrip packed int32" {
  let enc = @wire.Encoder::new()
  enc.write_packed_int32(1, [10, 20, 30])
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let values = dec.read_packed_int32()
  assert_eq(values.length(), 3)
  assert_eq(values[0], 10)
  assert_eq(values[1], 20)
  assert_eq(values[2], 30)
}

///|
test "skip unknown varint field" {
  let enc = @wire.Encoder::new()
  enc.write_int32(1, 100)
  enc.write_int32(99, 999)
  enc.write_string(2, "end")
  let dec = @wire.Decoder::new(enc.finish())
  let tag1 = dec.read_tag()
  assert_true(tag1.field_number == 1)
  assert_eq(dec.read_int32(), 100)
  let tag2 = dec.read_tag()
  assert_true(tag2.field_number == 99)
  dec.skip_field(tag2.wire_type)
  let tag3 = dec.read_tag()
  assert_true(tag3.field_number == 2)
  assert_eq(dec.read_string(), "end")
}

///|
test "roundtrip multiple fields" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Alice")
  enc.write_int32(2, 30)
  enc.write_bool(3, true)
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  assert_eq(dec.read_string(), "Alice")
  let _ = dec.read_tag()
  assert_eq(dec.read_int32(), 30)
  let _ = dec.read_tag()
  assert_eq(dec.read_bool(), true)
  assert_true(dec.is_at_end())
}
