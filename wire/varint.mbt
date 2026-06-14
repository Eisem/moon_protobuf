///|
pub fn encode_varint(buf : Array[Byte], value : UInt64) -> Unit {
  let mut v = value
  while v >= 0x80UL {
    buf.push(((v & 0x7FUL) | 0x80UL).to_byte())
    v = v >> 7
  }
  buf.push(v.to_byte())
}

///|
pub fn decode_varint(data : ArrayView[Byte]) -> (UInt64, Int) raise WireError {
  let mut result : UInt64 = 0UL
  let mut shift = 0
  for i in 0..<data.length() {
    let b = data[i]
    result = result | ((b.to_uint64() & 0x7FUL) << shift)
    if (b & 0x80) == 0 {
      return (result, i + 1)
    }
    shift = shift + 7
    if shift >= 64 {
      raise WireError::VarIntOverflow
    }
  }
  raise WireError::UnexpectedEndOfInput
}

///|
pub fn encode_zigzag32(value : Int) -> UInt {
  ((value << 1) ^ (value >> 31)).reinterpret_as_uint()
}

///|
pub fn decode_zigzag32(value : UInt) -> Int {
  (value >> 1).reinterpret_as_int() ^ -(value & 1).reinterpret_as_int()
}

///|
pub fn encode_zigzag64(value : Int64) -> UInt64 {
  ((value << 1) ^ (value >> 63)).reinterpret_as_uint64()
}

///|
pub fn decode_zigzag64(value : UInt64) -> Int64 {
  (value >> 1).reinterpret_as_int64() ^ -(value & 1UL).reinterpret_as_int64()
}
