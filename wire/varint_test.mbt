///|
test "encode_varint small value" {
  let buf : Array[Byte] = []
  @wire.encode_varint(buf, 1UL)
  debug_inspect(
    buf,
    content=(
      #|[0x01]
    ),
  )
}

///|
test "encode_varint 300" {
  let buf : Array[Byte] = []
  @wire.encode_varint(buf, 300UL)
  debug_inspect(
    buf,
    content=(
      #|[0xac, 0x02]
    ),
  )
}

///|
test "decode_varint single byte" {
  let data : Array[Byte] = [b'\x01']
  let (value, bytes_read) = @wire.decode_varint(data[:])
  assert_eq(value, 1UL)
  assert_eq(bytes_read, 1)
}

///|
test "decode_varint 300" {
  let data : Array[Byte] = [b'\xAC', b'\x02']
  let (value, bytes_read) = @wire.decode_varint(data[:])
  assert_eq(value, 300UL)
  assert_eq(bytes_read, 2)
}

///|
test "zigzag32 roundtrip" {
  assert_eq(@wire.decode_zigzag32(@wire.encode_zigzag32(0)), 0)
  assert_eq(@wire.decode_zigzag32(@wire.encode_zigzag32(-1)), -1)
  assert_eq(@wire.decode_zigzag32(@wire.encode_zigzag32(1)), 1)
  assert_eq(@wire.decode_zigzag32(@wire.encode_zigzag32(-2)), -2)
  assert_eq(
    @wire.decode_zigzag32(@wire.encode_zigzag32(2147483647)),
    2147483647,
  )
  assert_eq(
    @wire.decode_zigzag32(@wire.encode_zigzag32(-2147483648)),
    -2147483648,
  )
}

///|
test "zigzag64 roundtrip" {
  assert_eq(@wire.decode_zigzag64(@wire.encode_zigzag64(0L)), 0L)
  assert_eq(@wire.decode_zigzag64(@wire.encode_zigzag64(-1L)), -1L)
  assert_eq(@wire.decode_zigzag64(@wire.encode_zigzag64(1L)), 1L)
}

///|
test "tag encode/decode roundtrip" {
  let tag : @wire.Tag = { field_number: 1, wire_type: Varint }
  let encoded = tag.encode()
  let decoded = @wire.Tag::decode(encoded)
  assert_true(decoded == tag)
}
