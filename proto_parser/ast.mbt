///|
pub(all) enum ScalarType {
  Double
  Float
  Int32
  Int64
  UInt32
  UInt64
  SInt32
  SInt64
  Fixed32
  Fixed64
  SFixed32
  SFixed64
  Bool
  String_
  Bytes
} derive(Debug, Eq)

///|
pub(all) enum FieldType {
  Scalar(ScalarType)
  Message(String)
  Enum(String)
  MapType(key_type~ : ScalarType, value_type~ : FieldType)
} derive(Debug, Eq)

///|
pub(all) enum FieldLabel {
  Optional
  Repeated
  Required
} derive(Debug, Eq)

///|
pub(all) struct FieldDef {
  name : String
  field_type : FieldType
  label : FieldLabel
  number : Int
} derive(Debug, Eq)

///|
pub(all) struct EnumValueDef {
  name : String
  number : Int
} derive(Debug, Eq)

///|
pub(all) struct EnumDef {
  name : String
  values : Array[EnumValueDef]
} derive(Debug, Eq)

///|
pub(all) struct OneofFieldDef {
  name : String
  field_type : FieldType
  number : Int
} derive(Debug, Eq)

///|
pub(all) struct OneofDef {
  name : String
  fields : Array[OneofFieldDef]
} derive(Debug, Eq)

///|
pub(all) struct MessageDef {
  name : String
  fields : Array[FieldDef]
  oneofs : Array[OneofDef]
  nested_messages : Array[MessageDef]
  nested_enums : Array[EnumDef]
} derive(Debug, Eq)

///|
pub(all) struct ProtoFile {
  syntax : String
  package_name : String
  messages : Array[MessageDef]
  enums : Array[EnumDef]
} derive(Debug, Eq)
