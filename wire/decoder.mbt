///|
pub struct Decoder {
  data : Array[Byte]
  mut pos : Int
}

///|
pub fn Decoder::new(data : Array[Byte]) -> Decoder {
  { data, pos: 0 }
}

///|
pub fn Decoder::is_at_end(self : Decoder) -> Bool {
  self.pos >= self.data.length()
}

///|
pub fn Decoder::remaining(self : Decoder) -> Int {
  self.data.length() - self.pos
}

///|
fn Decoder::read_raw_varint(self : Decoder) -> UInt64 raise WireError {
  let mut result : UInt64 = 0UL
  let mut shift = 0
  while self.pos < self.data.length() {
    let b = self.data[self.pos]
    self.pos = self.pos + 1
    result = result | ((b.to_uint64() & 0x7FUL) << shift)
    if (b & 0x80) == 0 {
      return result
    }
    shift = shift + 7
    if shift >= 64 {
      raise WireError::VarIntOverflow
    }
  }
  raise WireError::UnexpectedEndOfInput
}

///|
fn Decoder::read_raw_little_endian32(self : Decoder) -> UInt raise WireError {
  if self.pos + 4 > self.data.length() {
    raise WireError::UnexpectedEndOfInput
  }
  let b0 = self.data[self.pos].to_uint()
  let b1 = self.data[self.pos + 1].to_uint()
  let b2 = self.data[self.pos + 2].to_uint()
  let b3 = self.data[self.pos + 3].to_uint()
  self.pos = self.pos + 4
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn Decoder::read_raw_little_endian64(self : Decoder) -> UInt64 raise WireError {
  if self.pos + 8 > self.data.length() {
    raise WireError::UnexpectedEndOfInput
  }
  let mut result : UInt64 = 0UL
  for i in 0..<8 {
    result = result | (self.data[self.pos + i].to_uint64() << (i * 8))
  }
  self.pos = self.pos + 8
  result
}

///|
fn Decoder::read_raw_bytes_arr(self : Decoder, count : Int) -> Array[Byte] raise WireError {
  if self.pos + count > self.data.length() {
    raise WireError::UnexpectedEndOfInput
  }
  let result : Array[Byte] = []
  for i in 0..<count {
    result.push(self.data[self.pos + i])
  }
  self.pos = self.pos + count
  result
}

///|
pub fn Decoder::read_tag(self : Decoder) -> Tag raise WireError {
  let value = self.read_raw_varint()
  let uint_val = value.to_uint()
  Tag::decode(uint_val)
}

///|
pub fn Decoder::read_int32(self : Decoder) -> Int raise WireError {
  let v = self.read_raw_varint()
  v.to_uint().reinterpret_as_int()
}

///|
pub fn Decoder::read_int64(self : Decoder) -> Int64 raise WireError {
  let v = self.read_raw_varint()
  v.reinterpret_as_int64()
}

///|
pub fn Decoder::read_uint32(self : Decoder) -> UInt raise WireError {
  let v = self.read_raw_varint()
  v.to_uint()
}

///|
pub fn Decoder::read_uint64(self : Decoder) -> UInt64 raise WireError {
  self.read_raw_varint()
}

///|
pub fn Decoder::read_sint32(self : Decoder) -> Int raise WireError {
  let v = self.read_raw_varint()
  decode_zigzag32(v.to_uint())
}

///|
pub fn Decoder::read_sint64(self : Decoder) -> Int64 raise WireError {
  let v = self.read_raw_varint()
  decode_zigzag64(v)
}

///|
pub fn Decoder::read_bool(self : Decoder) -> Bool raise WireError {
  let v = self.read_raw_varint()
  v != 0UL
}

///|
pub fn Decoder::read_fixed32(self : Decoder) -> UInt raise WireError {
  self.read_raw_little_endian32()
}

///|
pub fn Decoder::read_fixed64(self : Decoder) -> UInt64 raise WireError {
  self.read_raw_little_endian64()
}

///|
pub fn Decoder::read_sfixed32(self : Decoder) -> Int raise WireError {
  self.read_raw_little_endian32().reinterpret_as_int()
}

///|
pub fn Decoder::read_sfixed64(self : Decoder) -> Int64 raise WireError {
  self.read_raw_little_endian64().reinterpret_as_int64()
}

///|
pub fn Decoder::read_float(self : Decoder) -> Float raise WireError {
  let bits = self.read_raw_little_endian32()
  Float::reinterpret_from_uint(bits)
}

///|
pub fn Decoder::read_double(self : Decoder) -> Double raise WireError {
  let bits = self.read_raw_little_endian64()
  bits.reinterpret_as_double()
}

///|
pub fn Decoder::read_string(self : Decoder) -> String raise WireError {
  let len = self.read_raw_varint().to_uint().reinterpret_as_int()
  if self.pos + len > self.data.length() {
    raise WireError::TruncatedMessage
  }
  let byte_arr : Array[Byte] = []
  for i in 0..<len {
    byte_arr.push(self.data[self.pos + i])
  }
  self.pos = self.pos + len
  let bytes_data = Bytes::from_array(byte_arr[:])
  try {
    @utf8.decode(bytes_data[:])
  } catch {
    _ => raise WireError::InvalidUtf8
  }
}

///|
pub fn Decoder::read_bytes(self : Decoder) -> Array[Byte] raise WireError {
  let len = self.read_raw_varint().to_uint().reinterpret_as_int()
  self.read_raw_bytes_arr(len)
}

///|
pub fn Decoder::read_message(self : Decoder, decode_fn : (Decoder) -> Unit raise WireError) -> Unit raise WireError {
  let len = self.read_raw_varint().to_uint().reinterpret_as_int()
  if self.pos + len > self.data.length() {
    raise WireError::TruncatedMessage
  }
  let sub_data : Array[Byte] = []
  for i in 0..<len {
    sub_data.push(self.data[self.pos + i])
  }
  self.pos = self.pos + len
  let sub_decoder = Decoder::new(sub_data)
  decode_fn(sub_decoder)
}

///|
pub fn Decoder::read_packed_int32(self : Decoder) -> Array[Int] raise WireError {
  let len = self.read_raw_varint().to_uint().reinterpret_as_int()
  let end_pos = self.pos + len
  if end_pos > self.data.length() {
    raise WireError::TruncatedMessage
  }
  let result : Array[Int] = []
  while self.pos < end_pos {
    let v = self.read_raw_varint()
    result.push(v.to_uint().reinterpret_as_int())
  }
  result
}

///|
pub fn Decoder::read_packed_uint64(self : Decoder) -> Array[UInt64] raise WireError {
  let len = self.read_raw_varint().to_uint().reinterpret_as_int()
  let end_pos = self.pos + len
  if end_pos > self.data.length() {
    raise WireError::TruncatedMessage
  }
  let result : Array[UInt64] = []
  while self.pos < end_pos {
    let v = self.read_raw_varint()
    result.push(v)
  }
  result
}

///|
pub fn Decoder::skip_field(self : Decoder, wire_type : WireType) -> Unit raise WireError {
  match wire_type {
    Varint => { let _ = self.read_raw_varint() }
    Fixed64 => {
      if self.pos + 8 > self.data.length() {
        raise WireError::UnexpectedEndOfInput
      }
      self.pos = self.pos + 8
    }
    LengthDelimited => {
      let len = self.read_raw_varint().to_uint().reinterpret_as_int()
      if self.pos + len > self.data.length() {
        raise WireError::TruncatedMessage
      }
      self.pos = self.pos + len
    }
    Fixed32 => {
      if self.pos + 4 > self.data.length() {
        raise WireError::UnexpectedEndOfInput
      }
      self.pos = self.pos + 4
    }
  }
}
