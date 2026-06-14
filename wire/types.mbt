///|
pub(all) enum WireType {
  Varint
  Fixed64
  LengthDelimited
  Fixed32
} derive(Debug, Eq)

///|
pub fn WireType::from_int(value : Int) -> WireType raise WireError {
  match value {
    0 => Varint
    1 => Fixed64
    2 => LengthDelimited
    5 => Fixed32
    _ => raise WireError::InvalidWireType(value)
  }
}

///|
pub fn WireType::to_int(self : WireType) -> Int {
  match self {
    Varint => 0
    Fixed64 => 1
    LengthDelimited => 2
    Fixed32 => 5
  }
}

///|
pub(all) struct Tag {
  field_number : Int
  wire_type : WireType
} derive(Debug, Eq)

///|
pub fn Tag::encode(self : Tag) -> UInt {
  (self.field_number.reinterpret_as_uint() << 3) |
  self.wire_type.to_int().reinterpret_as_uint()
}

///|
pub fn Tag::decode(value : UInt) -> Tag raise WireError {
  let wire_type = WireType::from_int((value & 0x07).reinterpret_as_int())
  let field_number = (value >> 3).reinterpret_as_int()
  { field_number, wire_type }
}

///|
pub(all) suberror WireError {
  InvalidWireType(Int)
  UnexpectedEndOfInput
  VarIntOverflow
  InvalidUtf8
}
