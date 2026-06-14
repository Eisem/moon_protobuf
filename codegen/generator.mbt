///|
pub fn generate(file : @proto_parser.ProtoFile) -> String {
  let sb = StringBuilder::new()
  for msg in file.messages {
    sb.write_string(generate_message(msg))
    sb.write_string("\n")
  }
  for e in file.enums {
    sb.write_string(generate_enum(e))
    sb.write_string("\n")
  }
  sb.to_string()
}

///|
pub fn generate_message(msg : @proto_parser.MessageDef) -> String {
  let sb = StringBuilder::new()
  for oneof in msg.oneofs {
    sb.write_string(generate_oneof_enum(msg.name, oneof))
    sb.write_string("\n")
  }
  sb.write_string(generate_struct(msg))
  sb.write_string("\n")
  sb.write_string(generate_new(msg))
  sb.write_string("\n")
  sb.write_string(generate_encode(msg))
  sb.write_string("\n")
  sb.write_string(generate_decode(msg))
  sb.write_string("\n")
  for nested in msg.nested_messages {
    sb.write_string(generate_message(nested))
  }
  for nested_enum in msg.nested_enums {
    sb.write_string(generate_enum(nested_enum))
  }
  sb.to_string()
}

///|
fn generate_oneof_enum(msg_name : String, oneof : @proto_parser.OneofDef) -> String {
  let sb = StringBuilder::new()
  let enum_name = "\{msg_name}_\{capitalize(oneof.name)}"
  sb.write_string("///|\npub(all) enum \{enum_name} {\n")
  sb.write_string("  NotSet\n")
  for field in oneof.fields {
    let type_str = match field.field_type {
      Scalar(t) => scalar_to_moonbit_type(t)
      Message(name) => name
      Enum(name) => name
      MapType(..) => "String"
    }
    sb.write_string("  \{capitalize(field.name)}(\{type_str})\n")
  }
  sb.write_string("} derive(Debug, Eq)\n")
  sb.to_string()
}

///|
fn capitalize(s : String) -> String {
  if s.length() == 0 {
    return s
  }
  let first = match s.get_char(0) {
    Some(c) =>
      if c >= 'a' && c <= 'z' {
        Int::unsafe_to_char(c.to_int() - 32)
      } else {
        c
      }
    None => return s
  }
  let rest = s[1:].to_owned()
  "\{first}\{rest}"
}

///|
pub fn generate_enum(e : @proto_parser.EnumDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string("///|\npub(all) enum \{e.name} {\n")
  for v in e.values {
    sb.write_string("  \{v.name}\n")
  }
  sb.write_string("} derive(Debug, Eq)\n\n")
  sb.write_string("///|\npub fn \{e.name}::to_int(self : \{e.name}) -> Int {\n")
  sb.write_string("  match self {\n")
  for v in e.values {
    sb.write_string("    \{v.name} => \{v.number}\n")
  }
  sb.write_string("  }\n}\n\n")
  sb.write_string(
    "///|\npub fn \{e.name}::from_int(value : Int) -> \{e.name} {\n",
  )
  sb.write_string("  match value {\n")
  for v in e.values {
    sb.write_string("    \{v.number} => \{v.name}\n")
  }
  sb.write_string("    _ => \{e.values[0].name}\n")
  sb.write_string("  }\n}\n")
  sb.to_string()
}

///|
fn generate_struct(msg : @proto_parser.MessageDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string("///|\npub(all) struct \{msg.name} {\n")
  for field in msg.fields {
    let mbt_type = field_to_moonbit_type(field)
    sb.write_string("  \{field.name} : \{mbt_type}\n")
  }
  for oneof in msg.oneofs {
    let enum_name = "\{msg.name}_\{capitalize(oneof.name)}"
    sb.write_string("  \{oneof.name} : \{enum_name}\n")
  }
  sb.write_string("} derive(Debug, Eq)\n")
  sb.to_string()
}

///|
fn generate_new(msg : @proto_parser.MessageDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string("///|\npub fn \{msg.name}::new() -> \{msg.name} {\n")
  sb.write_string("  {\n")
  for field in msg.fields {
    let default_val = field_default_value(field)
    sb.write_string("    \{field.name}: \{default_val},\n")
  }
  for oneof in msg.oneofs {
    sb.write_string("    \{oneof.name}: NotSet,\n")
  }
  sb.write_string("  }\n}\n")
  sb.to_string()
}

///|
fn generate_encode(msg : @proto_parser.MessageDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "///|\npub fn \{msg.name}::encode(self : \{msg.name}) -> Array[Byte] {\n",
  )
  sb.write_string("  let encoder = @wire.Encoder::new()\n")
  for field in msg.fields {
    let num = field.number
    match field.label {
      Repeated =>
        match field.field_type {
          Scalar(scalar_type) =>
            if is_packable(scalar_type) {
              let write_method = packed_write_method(scalar_type)
              sb.write_string("  if self.\{field.name}.length() > 0 {\n")
              sb.write_string(
                "    encoder.\{write_method}(\{num}, self.\{field.name})\n",
              )
              sb.write_string("  }\n")
            } else {
              let write_method = scalar_write_method(scalar_type)
              sb.write_string("  for v in self.\{field.name} {\n")
              sb.write_string("    encoder.\{write_method}(\{num}, v)\n")
              sb.write_string("  }\n")
            }
          Message(_) => {
            sb.write_string("  for v in self.\{field.name} {\n")
            sb.write_string("    encoder.write_message(\{num}, (_enc) => {\n")
            sb.write_string("      let bytes = v.encode()\n")
            sb.write_string("      for b in bytes { _enc.buf.push(b) }\n")
            sb.write_string("    })\n")
            sb.write_string("  }\n")
          }
          Enum(_) => {
            sb.write_string("  for v in self.\{field.name} {\n")
            sb.write_string("    encoder.write_int32(\{num}, v.to_int())\n")
            sb.write_string("  }\n")
          }
          MapType(..) => ()
        }
      _ =>
        match field.field_type {
          Scalar(scalar_type) => {
            let write_method = scalar_write_method(scalar_type)
            let default_val = scalar_default_value(scalar_type)
            sb.write_string("  if self.\{field.name} != \{default_val} {\n")
            sb.write_string(
              "    encoder.\{write_method}(\{num}, self.\{field.name})\n",
            )
            sb.write_string("  }\n")
          }
          Message(type_name) => {
            sb.write_string("  match self.\{field.name} {\n")
            sb.write_string(
              "    Some(msg) => encoder.write_message(\{num}, (_enc) => {\n",
            )
            sb.write_string("      let bytes = msg.encode()\n")
            sb.write_string("      for b in bytes { _enc.buf.push(b) }\n")
            sb.write_string("    })\n")
            sb.write_string("    None => ()\n")
            sb.write_string("  }\n")
            ignore(type_name)
          }
          Enum(_) => {
            sb.write_string("  if self.\{field.name}.to_int() != 0 {\n")
            sb.write_string(
              "    encoder.write_int32(\{num}, self.\{field.name}.to_int())\n",
            )
            sb.write_string("  }\n")
          }
          MapType(key_type~, value_type~) => {
            let key_write = scalar_write_method(key_type)
            let val_write = match value_type {
              Scalar(t) => scalar_write_method(t)
              Message(_) => "write_bytes"
              _ => "write_string"
            }
            sb.write_string("  for k, v in self.\{field.name} {\n")
            sb.write_string("    encoder.write_message(\{num}, (_enc) => {\n")
            sb.write_string("      _enc.\{key_write}(1, k)\n")
            sb.write_string("      _enc.\{val_write}(2, v)\n")
            sb.write_string("    })\n")
            sb.write_string("  }\n")
          }
        }
    }
  }
  for oneof in msg.oneofs {
    let enum_name = "\{msg.name}_\{capitalize(oneof.name)}"
    sb.write_string("  match self.\{oneof.name} {\n")
    sb.write_string("    \{enum_name}::NotSet => ()\n")
    for ofield in oneof.fields {
      let variant = capitalize(ofield.name)
      let write_method = match ofield.field_type {
        Scalar(t) => scalar_write_method(t)
        Message(_) => "write_bytes"
        _ => "write_string"
      }
      sb.write_string("    \{enum_name}::\{variant}(v) => encoder.\{write_method}(\{ofield.number}, v)\n")
    }
    sb.write_string("  }\n")
  }
  sb.write_string("  encoder.finish()\n}\n")
  sb.to_string()
}

///|
fn generate_decode(msg : @proto_parser.MessageDef) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "///|\npub fn \{msg.name}::decode(data : Array[Byte]) -> \{msg.name} raise @wire.WireError {\n",
  )
  sb.write_string("  let decoder = @wire.Decoder::new(data)\n")
  for field in msg.fields {
    let default_val = field_default_value(field)
    sb.write_string("  let mut _f\{field.number} = \{default_val}\n")
  }
  for oneof in msg.oneofs {
    let enum_name = "\{msg.name}_\{capitalize(oneof.name)}"
    sb.write_string("  let mut _oneof_\{oneof.name} : \{enum_name} = NotSet\n")
  }
  sb.write_string("  while !(decoder.is_at_end()) {\n")
  sb.write_string("    let tag = decoder.read_tag()\n")
  sb.write_string("    match tag.field_number {\n")
  for field in msg.fields {
    let num = field.number
    match field.label {
      Repeated =>
        match field.field_type {
          Scalar(scalar_type) =>
            if is_packable(scalar_type) {
              let read_method = packed_read_method(scalar_type)
              sb.write_string(
                "      \{num} => _f\{num} = decoder.\{read_method}()\n",
              )
            } else {
              let read_method = scalar_read_method(scalar_type)
              sb.write_string(
                "      \{num} => _f\{num}.push(decoder.\{read_method}())\n",
              )
            }
          Message(type_name) => {
            sb.write_string("      \{num} => {\n")
            sb.write_string("        let msg_bytes = decoder.read_bytes()\n")
            sb.write_string(
              "        _f\{num}.push(\{type_name}::decode(msg_bytes))\n",
            )
            sb.write_string("      }\n")
          }
          Enum(_) =>
            sb.write_string(
              "      \{num} => _f\{num}.push(decoder.read_int32())\n",
            )
          MapType(..) => ()
        }
      _ =>
        match field.field_type {
          Scalar(scalar_type) => {
            let read_method = scalar_read_method(scalar_type)
            sb.write_string(
              "      \{num} => _f\{num} = decoder.\{read_method}()\n",
            )
          }
          Message(type_name) => {
            sb.write_string("      \{num} => {\n")
            sb.write_string("        let msg_bytes = decoder.read_bytes()\n")
            sb.write_string(
              "        _f\{num} = Some(\{type_name}::decode(msg_bytes))\n",
            )
            sb.write_string("      }\n")
          }
          Enum(_) =>
            sb.write_string("      \{num} => _f\{num} = decoder.read_int32()\n")
          MapType(key_type~, value_type~) => {
            let key_read = scalar_read_method(key_type)
            let val_read = match value_type {
              Scalar(t) => scalar_read_method(t)
              Message(_) => "read_bytes"
              _ => "read_string"
            }
            sb.write_string("      \{num} => {\n")
            sb.write_string("        decoder.read_message((_entry_dec) => {\n")
            sb.write_string("          let mut _k = \{scalar_default_value(key_type)}\n")
            let val_default = match value_type { Scalar(t) => scalar_default_value(t); _ => "\"\"" }
            sb.write_string("          let mut _v = \{val_default}\n")
            sb.write_string("          while !(_entry_dec.is_at_end()) {\n")
            sb.write_string("            let etag = _entry_dec.read_tag()\n")
            sb.write_string("            match etag.field_number {\n")
            sb.write_string("              1 => _k = _entry_dec.\{key_read}()\n")
            sb.write_string("              2 => _v = _entry_dec.\{val_read}()\n")
            sb.write_string("              _ => _entry_dec.skip_field(etag.wire_type)\n")
            sb.write_string("            }\n")
            sb.write_string("          }\n")
            sb.write_string("          _f\{num}[_k] = _v\n")
            sb.write_string("        })\n")
            sb.write_string("      }\n")
          }
        }
    }
  }
  for oneof in msg.oneofs {
    let enum_name = "\{msg.name}_\{capitalize(oneof.name)}"
    for ofield in oneof.fields {
      let variant = capitalize(ofield.name)
      let read_method = match ofield.field_type {
        Scalar(t) => scalar_read_method(t)
        Message(_) => "read_bytes"
        _ => "read_string"
      }
      sb.write_string("      \{ofield.number} => _oneof_\{oneof.name} = \{enum_name}::\{variant}(decoder.\{read_method}())\n")
    }
  }
  sb.write_string("      _ => decoder.skip_field(tag.wire_type)\n")
  sb.write_string("    }\n")
  sb.write_string("  }\n")
  sb.write_string("  {\n")
  for field in msg.fields {
    sb.write_string("    \{field.name}: _f\{field.number},\n")
  }
  for oneof in msg.oneofs {
    sb.write_string("    \{oneof.name}: _oneof_\{oneof.name},\n")
  }
  sb.write_string("  }\n}\n")
  sb.to_string()
}

///|
fn field_to_moonbit_type(field : @proto_parser.FieldDef) -> String {
  match field.field_type {
    MapType(key_type~, value_type~) => {
      let key_t = scalar_to_moonbit_type(key_type)
      let val_t = match value_type {
        Scalar(t) => scalar_to_moonbit_type(t)
        Message(name) => name
        Enum(name) => name
        MapType(..) => "Map[String, String]"
      }
      "Map[\{key_t}, \{val_t}]"
    }
    _ => {
      let base = match field.field_type {
        Scalar(t) => scalar_to_moonbit_type(t)
        Message(name) => name
        Enum(name) => name
        MapType(..) => ""
      }
      match field.label {
        Repeated => "Array[\{base}]"
        _ =>
          match field.field_type {
            Message(_) => "\{base}?"
            _ => base
          }
      }
    }
  }
}

///|
fn field_default_value(field : @proto_parser.FieldDef) -> String {
  match field.field_type {
    MapType(..) => "Map::from_array([])"
    _ =>
      match field.label {
        Repeated => "[]"
        _ =>
          match field.field_type {
            Scalar(t) => scalar_default_value(t)
            Message(_) => "None"
            Enum(_) => "0"
            MapType(..) => "Map::from_array([])"
          }
      }
  }
}

///|
fn scalar_to_moonbit_type(t : @proto_parser.ScalarType) -> String {
  match t {
    Double => "Double"
    Float => "Float"
    Int32 | SInt32 | SFixed32 => "Int"
    Int64 | SInt64 | SFixed64 => "Int64"
    UInt32 | Fixed32 => "UInt"
    UInt64 | Fixed64 => "UInt64"
    Bool => "Bool"
    String_ => "String"
    Bytes => "Array[Byte]"
  }
}

///|
fn scalar_default_value(t : @proto_parser.ScalarType) -> String {
  match t {
    Double => "0.0"
    Float => "0.0"
    Int32 | SInt32 | SFixed32 => "0"
    Int64 | SInt64 | SFixed64 => "0L"
    UInt32 | Fixed32 => "0U"
    UInt64 | Fixed64 => "0UL"
    Bool => "false"
    String_ => "\"\""
    Bytes => "[]"
  }
}

///|
fn scalar_write_method(t : @proto_parser.ScalarType) -> String {
  match t {
    Double => "write_double"
    Float => "write_float"
    Int32 => "write_int32"
    Int64 => "write_int64"
    UInt32 => "write_uint32"
    UInt64 => "write_uint64"
    SInt32 => "write_sint32"
    SInt64 => "write_sint64"
    Fixed32 => "write_fixed32"
    Fixed64 => "write_fixed64"
    SFixed32 => "write_sfixed32"
    SFixed64 => "write_sfixed64"
    Bool => "write_bool"
    String_ => "write_string"
    Bytes => "write_bytes"
  }
}

///|
fn scalar_read_method(t : @proto_parser.ScalarType) -> String {
  match t {
    Double => "read_double"
    Float => "read_float"
    Int32 => "read_int32"
    Int64 => "read_int64"
    UInt32 => "read_uint32"
    UInt64 => "read_uint64"
    SInt32 => "read_sint32"
    SInt64 => "read_sint64"
    Fixed32 => "read_fixed32"
    Fixed64 => "read_fixed64"
    SFixed32 => "read_sfixed32"
    SFixed64 => "read_sfixed64"
    Bool => "read_bool"
    String_ => "read_string"
    Bytes => "read_bytes"
  }
}

///|
fn is_packable(t : @proto_parser.ScalarType) -> Bool {
  match t {
    String_ | Bytes => false
    _ => true
  }
}

///|
fn packed_write_method(t : @proto_parser.ScalarType) -> String {
  match t {
    Int32 | SInt32 | SFixed32 => "write_packed_int32"
    UInt64 | Fixed64 | Int64 | SInt64 | SFixed64 => "write_packed_uint64"
    Float | UInt32 | Fixed32 => "write_packed_float"
    Double => "write_packed_double"
    Bool => "write_packed_int32"
    _ => "write_packed_int32"
  }
}

///|
fn packed_read_method(t : @proto_parser.ScalarType) -> String {
  match t {
    Int32 | SInt32 | SFixed32 => "read_packed_int32"
    UInt64 | Fixed64 | Int64 | SInt64 | SFixed64 => "read_packed_uint64"
    Float | UInt32 | Fixed32 => "read_packed_int32"
    Double => "read_packed_uint64"
    Bool => "read_packed_int32"
    _ => "read_packed_int32"
  }
}
