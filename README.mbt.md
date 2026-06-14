# moon_protobuf

A Protocol Buffers (proto3) encoding/decoding library for MoonBit.

## Features

- **Wire Format**: Full proto3 binary wire format encoder/decoder
- **Proto Parser**: Parse `.proto` files into AST
- **Code Generator**: Generate MoonBit structs with encode/decode methods
- **Type Support**: All proto3 scalar types, nested messages, repeated fields, enums

## Installation

```sh
moon add Eisem/moon_protobuf
```

## Quick Start

### Wire Format (Manual Encoding/Decoding)

```mbt check
///|
test {
  // Encode
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Alice")
  enc.write_int32(2, 30)
  let data = enc.finish()
  // Decode
  let dec = @wire.Decoder::new(data)
  let _ = dec.read_tag()
  let name = dec.read_string()
  let _ = dec.read_tag()
  let age = dec.read_int32()
  assert_eq(name, "Alice")
  assert_eq(age, 30)
}
```

### Proto File Parsing

```mbt check
///|
test {
  let proto =
    #|syntax = "proto3";
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|}
  let file = @proto_parser.parse(proto)
  assert_eq(file.messages[0].name, "Person")
  assert_eq(file.messages[0].fields.length(), 2)
}
```

### Code Generation

```mbt check
///|
test {
  let proto =
    #|syntax = "proto3";
    #|message Point {
    #|  double x = 1;
    #|  double y = 2;
    #|}
  let file = @proto_parser.parse(proto)
  let code = @codegen.generate(file)
  assert_true(code.contains("pub(all) struct Point"))
  assert_true(code.contains("Point::encode"))
  assert_true(code.contains("Point::decode"))
}
```

## Supported Proto3 Types

| Proto Type | MoonBit Type | Wire Type |
|---|---|---|
| double | Double | Fixed64 |
| float | Float | Fixed32 |
| int32 | Int | Varint |
| int64 | Int64 | Varint |
| uint32 | UInt | Varint |
| uint64 | UInt64 | Varint |
| sint32 | Int | Varint (ZigZag) |
| sint64 | Int64 | Varint (ZigZag) |
| fixed32 | UInt | Fixed32 |
| fixed64 | UInt64 | Fixed64 |
| sfixed32 | Int | Fixed32 |
| sfixed64 | Int64 | Fixed64 |
| bool | Bool | Varint |
| string | String | LengthDelimited |
| bytes | Array[Byte] | LengthDelimited |
| message | T? | LengthDelimited |
| repeated | Array[T] | Packed/LengthDelimited |

## Project Structure

```
moon_protobuf/
├── wire/           # Wire format encoder/decoder
├── proto_parser/   # Proto3 file lexer and parser
├── codegen/        # MoonBit code generator
├── integration/    # Integration tests
└── cmd/main/       # CLI demo
```

## Running

```sh
moon test           # Run all tests
moon run cmd/main   # Run CLI demo
```

## License

Apache-2.0
