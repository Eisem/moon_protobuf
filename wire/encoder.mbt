///|
pub struct Encoder {
  buf : Array[Byte]
}

///|
pub fn Encoder::new() -> Encoder {
  { buf: [] }
}

///|
fn Encoder::write_tag(self : Encoder, field_number : Int, wire_type : WireType) -> Unit {
  let tag_value = (field_number.reinterpret_as_uint() << 3) | wire_type.to_int().reinterpret_as_uint()
  encode_varint(self.buf, tag_value.to_uint64())
}

///|
fn Encoder::write_raw_varint32(self : Encoder, value : Int) -> Unit {
  encode_varint(self.buf, value.reinterpret_as_uint().to_uint64())
}

///|
fn Encoder::write_raw_varint64(self : Encoder, value : Int64) -> Unit {
  encode_varint(self.buf, value.reinterpret_as_uint64())
}

///|
fn Encoder::write_raw_little_endian32(self : Encoder, value : UInt) -> Unit {
  self.buf.push((value & 0xFF).to_byte())
  self.buf.push(((value >> 8) & 0xFF).to_byte())
  self.buf.push(((value >> 16) & 0xFF).to_byte())
  self.buf.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn Encoder::write_raw_little_endian64(self : Encoder, value : UInt64) -> Unit {
  self.buf.push((value & 0xFFUL).to_byte())
  self.buf.push(((value >> 8) & 0xFFUL).to_byte())
  self.buf.push(((value >> 16) & 0xFFUL).to_byte())
  self.buf.push(((value >> 24) & 0xFFUL).to_byte())
  self.buf.push(((value >> 32) & 0xFFUL).to_byte())
  self.buf.push(((value >> 40) & 0xFFUL).to_byte())
  self.buf.push(((value >> 48) & 0xFFUL).to_byte())
  self.buf.push(((value >> 56) & 0xFFUL).to_byte())
}

///|
fn Encoder::write_raw_bytes(self : Encoder, data : Bytes) -> Unit {
  for i in 0..<data.length() {
    self.buf.push(data[i])
  }
}

///|
pub fn Encoder::write_int32(self : Encoder, field_number : Int, value : Int) -> Unit {
  self.write_tag(field_number, Varint)
  self.write_raw_varint32(value)
}

///|
pub fn Encoder::write_int64(self : Encoder, field_number : Int, value : Int64) -> Unit {
  self.write_tag(field_number, Varint)
  self.write_raw_varint64(value)
}

///|
pub fn Encoder::write_uint32(self : Encoder, field_number : Int, value : UInt) -> Unit {
  self.write_tag(field_number, Varint)
  encode_varint(self.buf, value.to_uint64())
}

///|
pub fn Encoder::write_uint64(self : Encoder, field_number : Int, value : UInt64) -> Unit {
  self.write_tag(field_number, Varint)
  encode_varint(self.buf, value)
}

///|
pub fn Encoder::write_sint32(self : Encoder, field_number : Int, value : Int) -> Unit {
  self.write_tag(field_number, Varint)
  encode_varint(self.buf, encode_zigzag32(value).to_uint64())
}

///|
pub fn Encoder::write_sint64(self : Encoder, field_number : Int, value : Int64) -> Unit {
  self.write_tag(field_number, Varint)
  encode_varint(self.buf, encode_zigzag64(value))
}

///|
pub fn Encoder::write_bool(self : Encoder, field_number : Int, value : Bool) -> Unit {
  self.write_tag(field_number, Varint)
  self.buf.push(if value { b'\x01' } else { b'\x00' })
}

///|
pub fn Encoder::write_fixed32(self : Encoder, field_number : Int, value : UInt) -> Unit {
  self.write_tag(field_number, Fixed32)
  self.write_raw_little_endian32(value)
}

///|
pub fn Encoder::write_fixed64(self : Encoder, field_number : Int, value : UInt64) -> Unit {
  self.write_tag(field_number, Fixed64)
  self.write_raw_little_endian64(value)
}

///|
pub fn Encoder::write_sfixed32(self : Encoder, field_number : Int, value : Int) -> Unit {
  self.write_tag(field_number, Fixed32)
  self.write_raw_little_endian32(value.reinterpret_as_uint())
}

///|
pub fn Encoder::write_sfixed64(self : Encoder, field_number : Int, value : Int64) -> Unit {
  self.write_tag(field_number, Fixed64)
  self.write_raw_little_endian64(value.reinterpret_as_uint64())
}

///|
pub fn Encoder::write_float(self : Encoder, field_number : Int, value : Float) -> Unit {
  self.write_tag(field_number, Fixed32)
  self.write_raw_little_endian32(value.reinterpret_as_uint())
}

///|
pub fn Encoder::write_double(self : Encoder, field_number : Int, value : Double) -> Unit {
  self.write_tag(field_number, Fixed64)
  self.write_raw_little_endian64(value.reinterpret_as_uint64())
}

///|
pub fn Encoder::write_string(self : Encoder, field_number : Int, value : String) -> Unit {
  let utf8_bytes = @utf8.encode(value)
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, utf8_bytes.length().reinterpret_as_uint().to_uint64())
  self.write_raw_bytes(utf8_bytes)
}

///|
pub fn Encoder::write_bytes(self : Encoder, field_number : Int, value : Array[Byte]) -> Unit {
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, value.length().reinterpret_as_uint().to_uint64())
  for b in value {
    self.buf.push(b)
  }
}

///|
pub fn Encoder::write_message(self : Encoder, field_number : Int, encode_fn : (Encoder) -> Unit) -> Unit {
  let sub = Encoder::new()
  encode_fn(sub)
  let sub_bytes = sub.buf
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, sub_bytes.length().reinterpret_as_uint().to_uint64())
  for b in sub_bytes {
    self.buf.push(b)
  }
}

///|
pub fn Encoder::write_packed_int32(self : Encoder, field_number : Int, values : Array[Int]) -> Unit {
  let sub : Array[Byte] = []
  for v in values {
    encode_varint(sub, v.reinterpret_as_uint().to_uint64())
  }
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, sub.length().reinterpret_as_uint().to_uint64())
  for b in sub {
    self.buf.push(b)
  }
}

///|
pub fn Encoder::write_packed_uint64(self : Encoder, field_number : Int, values : Array[UInt64]) -> Unit {
  let sub : Array[Byte] = []
  for v in values {
    encode_varint(sub, v)
  }
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, sub.length().reinterpret_as_uint().to_uint64())
  for b in sub {
    self.buf.push(b)
  }
}

///|
pub fn Encoder::write_packed_float(self : Encoder, field_number : Int, values : Array[Float]) -> Unit {
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, (values.length() * 4).reinterpret_as_uint().to_uint64())
  for v in values {
    self.write_raw_little_endian32(v.reinterpret_as_uint())
  }
}

///|
pub fn Encoder::write_packed_double(self : Encoder, field_number : Int, values : Array[Double]) -> Unit {
  self.write_tag(field_number, LengthDelimited)
  encode_varint(self.buf, (values.length() * 8).reinterpret_as_uint().to_uint64())
  for v in values {
    self.write_raw_little_endian64(v.reinterpret_as_uint64())
  }
}

///|
pub fn Encoder::finish(self : Encoder) -> Array[Byte] {
  self.buf
}

///|
pub fn Encoder::len(self : Encoder) -> Int {
  self.buf.length()
}
