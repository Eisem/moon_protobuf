///|
test "encode int32 field" {
  let enc = @wire.Encoder::new()
  enc.write_int32(1, 150)
  debug_inspect(enc.finish(), content=(
    #|[0x08, 0x96, 0x01]
  ))
}

///|
test "encode bool field" {
  let enc = @wire.Encoder::new()
  enc.write_bool(1, true)
  debug_inspect(enc.finish(), content=(
    #|[0x08, 0x01]
  ))
}

///|
test "encode string field" {
  let enc = @wire.Encoder::new()
  enc.write_string(2, "testing")
  debug_inspect(enc.finish(), content=(
    #|[0x12, 0x07, 0x74, 0x65, 0x73, 0x74, 0x69, 0x6e, 0x67]
  ))
}

///|
test "encode fixed32 field" {
  let enc = @wire.Encoder::new()
  enc.write_fixed32(1, 0x01020304U)
  debug_inspect(enc.finish(), content=(
    #|[0x0d, 0x04, 0x03, 0x02, 0x01]
  ))
}

///|
test "encode double field" {
  let enc = @wire.Encoder::new()
  enc.write_double(1, 1.0)
  debug_inspect(enc.finish(), content=(
    #|[0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x3f]
  ))
}

///|
test "encode sint32 negative" {
  let enc = @wire.Encoder::new()
  enc.write_sint32(1, -1)
  debug_inspect(enc.finish(), content=(
    #|[0x08, 0x01]
  ))
}

///|
test "encode multiple fields" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Alice")
  enc.write_int32(2, 30)
  assert_true(enc.len() > 0)
  debug_inspect(enc.finish(), content=(
    #|[0x0a, 0x05, 0x41, 0x6c, 0x69, 0x63, 0x65, 0x10, 0x1e]
  ))
}

///|
test "encode nested message" {
  let enc = @wire.Encoder::new()
  enc.write_message(1, fn(sub) { sub.write_int32(1, 42) })
  debug_inspect(enc.finish(), content=(
    #|[0x0a, 0x02, 0x08, 0x2a]
  ))
}

///|
test "encode packed int32" {
  let enc = @wire.Encoder::new()
  enc.write_packed_int32(1, [1, 2, 3])
  debug_inspect(enc.finish(), content=(
    #|[0x0a, 0x03, 0x01, 0x02, 0x03]
  ))
}
