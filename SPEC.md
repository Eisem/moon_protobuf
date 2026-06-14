# moon_protobuf 项目规范

## 1. 项目概述

**名称：** moon_protobuf  
**定位：** MoonBit 生态中的 Protocol Buffers (proto3) 编解码库  
**功能：** 提供 proto3 文件解析、二进制 wire format 编解码、MoonBit 代码生成三大能力  
**目标用户：** 需要跨语言数据交换、网络通信序列化的 MoonBit 开发者  
**参考实现：** Rust `prost`、Go `protobuf`、Python `betterproto`

---

## 2. 包结构

```
moon_protobuf/
├── moon.mod                    # 模块元数据
├── moon.pkg                    # 根包（re-export 核心类型）
├── wire/                       # Wire Format 编解码
│   ├── moon.pkg
│   ├── types.mbt               # WireType, Tag, WireError
│   ├── varint.mbt              # Varint/ZigZag 编解码
│   ├── encoder.mbt             # 编码器
│   ├── decoder.mbt             # 解码器
│   ├── varint_test.mbt
│   ├── encoder_test.mbt
│   ├── decoder_test.mbt
│   └── nested_test.mbt
├── proto_parser/               # Proto3 文件解析
│   ├── moon.pkg
│   ├── ast.mbt                 # AST 类型定义
│   ├── lexer.mbt               # 词法分析器
│   ├── parser.mbt              # 语法分析器
│   ├── lexer_test.mbt
│   └── parser_test.mbt
├── codegen/                    # MoonBit 代码生成
│   ├── moon.pkg
│   ├── generator.mbt           # 代码生成器
│   └── generator_test.mbt
├── cmd/main/                   # CLI 入口
│   ├── moon.pkg
│   └── main.mbt
└── examples/                   # 使用示例
    ├── moon.pkg
    └── basic_usage.mbt
```

---

## 3. wire 包规范

### 3.1 类型定义 (`types.mbt`)

```
pub(all) enum WireType {
  Varint          // wire type 0: int32, int64, uint32, uint64, sint32, sint64, bool, enum
  Fixed64         // wire type 1: fixed64, sfixed64, double
  LengthDelimited // wire type 2: string, bytes, embedded messages, packed repeated
  Fixed32         // wire type 5: fixed32, sfixed32, float
}

pub(all) struct Tag {
  field_number : Int
  wire_type : WireType
}

pub(all) suberror WireError {
  InvalidWireType(Int)
  UnexpectedEndOfInput
  VarIntOverflow
  InvalidUtf8
  InvalidFieldNumber(Int)
  TruncatedMessage
}
```

### 3.2 Varint 编解码 (`varint.mbt`)

| 函数 | 签名 | 说明 |
|---|---|---|
| `encode_varint` | `(Array[Byte], UInt64) -> Unit` | 将 uint64 编码为变长字节追加到 buf |
| `decode_varint` | `(ArrayView[Byte]) -> (UInt64, Int) raise WireError` | 解码 varint，返回 (值, 消耗字节数) |
| `encode_zigzag32` | `(Int) -> UInt` | 有符号→无符号 ZigZag 映射 |
| `decode_zigzag32` | `(UInt) -> Int` | 无符号→有符号 ZigZag 逆映射 |
| `encode_zigzag64` | `(Int64) -> UInt64` | 64位 ZigZag 编码 |
| `decode_zigzag64` | `(UInt64) -> Int64` | 64位 ZigZag 解码 |

### 3.3 编码器 (`encoder.mbt`)

```
pub struct Encoder {
  buf : Array[Byte]
}

// 构造
pub fn Encoder::new() -> Encoder

// 标量字段编码 — 每个方法写入 tag + value
pub fn Encoder::write_int32(self, field_number: Int, value: Int) -> Unit
pub fn Encoder::write_int64(self, field_number: Int, value: Int64) -> Unit
pub fn Encoder::write_uint32(self, field_number: Int, value: UInt) -> Unit
pub fn Encoder::write_uint64(self, field_number: Int, value: UInt64) -> Unit
pub fn Encoder::write_sint32(self, field_number: Int, value: Int) -> Unit
pub fn Encoder::write_sint64(self, field_number: Int, value: Int64) -> Unit
pub fn Encoder::write_bool(self, field_number: Int, value: Bool) -> Unit
pub fn Encoder::write_float(self, field_number: Int, value: Float) -> Unit
pub fn Encoder::write_double(self, field_number: Int, value: Double) -> Unit
pub fn Encoder::write_fixed32(self, field_number: Int, value: UInt) -> Unit
pub fn Encoder::write_fixed64(self, field_number: Int, value: UInt64) -> Unit
pub fn Encoder::write_sfixed32(self, field_number: Int, value: Int) -> Unit
pub fn Encoder::write_sfixed64(self, field_number: Int, value: Int64) -> Unit
pub fn Encoder::write_string(self, field_number: Int, value: String) -> Unit
pub fn Encoder::write_bytes(self, field_number: Int, value: Array[Byte]) -> Unit

// 嵌套 message
pub fn Encoder::write_message(self, field_number: Int, encode_fn: (Encoder) -> Unit) -> Unit

// Repeated (packed encoding)
pub fn Encoder::write_packed_int32(self, field_number: Int, values: Array[Int]) -> Unit
pub fn Encoder::write_packed_uint64(self, field_number: Int, values: Array[UInt64]) -> Unit
pub fn Encoder::write_packed_float(self, field_number: Int, values: Array[Float]) -> Unit
pub fn Encoder::write_packed_double(self, field_number: Int, values: Array[Double]) -> Unit

// 输出
pub fn Encoder::finish(self) -> Array[Byte]
pub fn Encoder::len(self) -> Int
```

**编码规则：**
- tag 编码：`(field_number << 3) | wire_type`，作为 varint 写入
- Varint 类型：直接写 varint（bool 为 0/1，enum 为 int32）
- Fixed32：小端序写 4 字节
- Fixed64：小端序写 8 字节
- LengthDelimited：先写长度(varint)，再写 payload
- 嵌套 message：先编码到临时 buffer，计算长度，再写入主 buffer
- Packed repeated：所有值编码到一个 length-delimited 字段中
- Proto3 默认值（0/""/false）跳过不编码（节省空间）

### 3.4 解码器 (`decoder.mbt`)

```
pub struct Decoder {
  data : Array[Byte]
  mut pos : Int
}

// 构造
pub fn Decoder::new(data: Array[Byte]) -> Decoder

// 状态
pub fn Decoder::is_at_end(self) -> Bool
pub fn Decoder::remaining(self) -> Int

// Tag 读取
pub fn Decoder::read_tag(self) -> Tag raise WireError

// 标量字段解码
pub fn Decoder::read_int32(self) -> Int raise WireError
pub fn Decoder::read_int64(self) -> Int64 raise WireError
pub fn Decoder::read_uint32(self) -> UInt raise WireError
pub fn Decoder::read_uint64(self) -> UInt64 raise WireError
pub fn Decoder::read_sint32(self) -> Int raise WireError
pub fn Decoder::read_sint64(self) -> Int64 raise WireError
pub fn Decoder::read_bool(self) -> Bool raise WireError
pub fn Decoder::read_float(self) -> Float raise WireError
pub fn Decoder::read_double(self) -> Double raise WireError
pub fn Decoder::read_fixed32(self) -> UInt raise WireError
pub fn Decoder::read_fixed64(self) -> UInt64 raise WireError
pub fn Decoder::read_sfixed32(self) -> Int raise WireError
pub fn Decoder::read_sfixed64(self) -> Int64 raise WireError
pub fn Decoder::read_string(self) -> String raise WireError
pub fn Decoder::read_bytes(self) -> Array[Byte] raise WireError

// 嵌套 message
pub fn Decoder::read_message(self, decode_fn: (Decoder) -> Unit raise WireError) -> Unit raise WireError

// Repeated (packed)
pub fn Decoder::read_packed_int32(self) -> Array[Int] raise WireError
pub fn Decoder::read_packed_uint64(self) -> Array[UInt64] raise WireError

// 跳过未知字段
pub fn Decoder::skip_field(self, wire_type: WireType) -> Unit raise WireError
```

**解码规则：**
- `read_tag()` 读一个 varint，拆分为 field_number 和 wire_type
- 根据 wire_type 决定如何读取 payload：
  - Varint(0)：读一个 varint
  - Fixed64(1)：读 8 字节小端序
  - LengthDelimited(2)：先读长度 varint，再读 payload
  - Fixed32(5)：读 4 字节小端序
- `skip_field` 用于跳过不识别的字段号（前向兼容）

---

## 4. proto_parser 包规范

### 4.1 AST 类型 (`ast.mbt`)

```
pub(all) enum ScalarType {
  Double | Float | Int32 | Int64 | UInt32 | UInt64 |
  SInt32 | SInt64 | Fixed32 | Fixed64 | SFixed32 | SFixed64 |
  Bool | String_ | Bytes
}

pub(all) enum FieldType {
  Scalar(ScalarType)
  Message(String)    // 消息类型名
  Enum(String)       // 枚举类型名
}

pub(all) enum FieldLabel {
  Optional | Repeated | Required
}

pub(all) struct FieldDef {
  name : String
  field_type : FieldType
  label : FieldLabel
  number : Int
}

pub(all) struct EnumValueDef {
  name : String
  number : Int
}

pub(all) struct EnumDef {
  name : String
  values : Array[EnumValueDef]
}

pub(all) struct MessageDef {
  name : String
  fields : Array[FieldDef]
  nested_messages : Array[MessageDef]
  nested_enums : Array[EnumDef]
}

pub(all) struct ProtoFile {
  syntax : String
  package_name : String
  messages : Array[MessageDef]
  enums : Array[EnumDef]
}
```

### 4.2 词法分析器 (`lexer.mbt`)

**Token 类型：**
```
pub(all) enum TokenKind {
  // 关键字
  Syntax | Message | Enum | Repeated | Optional |
  Required | Reserved | Package | Import | Oneof | Map |
  // 类型关键字
  TDouble | TFloat | TInt32 | TInt64 | TUint32 | TUint64 |
  TSint32 | TSint64 | TFixed32 | TFixed64 | TSfixed32 | TSfixed64 |
  TBool | TString | TBytes |
  // 字面量
  Ident(String) | IntLit(Int) | StringLit(String) |
  // 符号
  LBrace | RBrace | LParen | RParen | LBracket | RBracket |
  Semicolon | Equals | Comma | Dot |
  // 其他
  Eof
}

pub(all) struct Token {
  kind : TokenKind
  line : Int
  col : Int
}
```

**词法规则：**
- 标识符：`[a-zA-Z_][a-zA-Z0-9_]*`
- 整数字面量：`[0-9]+`
- 字符串字面量：`"..."` 或 `'...'`
- 注释：`//` 行注释，`/* */` 块注释（跳过）
- 空白：跳过
- 关键字在标识符识别后做查表匹配

**公开 API：**
```
pub fn Lexer::new(input: String) -> Lexer
pub fn Lexer::tokenize(self) -> Array[Token] raise ParseError
```

### 4.3 语法分析器 (`parser.mbt`)

**支持的 Proto3 语法子集：**
```
proto_file = syntax_decl { message_def | enum_def | package_decl }
syntax_decl = "syntax" "=" string_lit ";"
package_decl = "package" ident { "." ident } ";"
message_def = "message" ident "{" { field_def | enum_def | message_def } "}"
field_def = [ "repeated" | "optional" ] type ident "=" int_lit ";"
enum_def = "enum" ident "{" { enum_value_def } "}"
enum_value_def = ident "=" int_lit ";"
type = scalar_type | ident
```

**公开 API：**
```
pub fn parse(input: String) -> ProtoFile raise ParseError

pub(all) suberror ParseError {
  UnexpectedToken(expected~ : String, got~ : String, line~ : Int, col~ : Int)
  UnexpectedEof(expected~ : String)
  InvalidSyntax(message~ : String, line~ : Int, col~ : Int)
}
```

---

## 5. codegen 包规范

### 5.1 代码生成器 (`generator.mbt`)

**输入：** `ProtoFile`（解析后的 AST）  
**输出：** `String`（生成的 MoonBit 源代码）

**生成规则：**

对于每个 `MessageDef`，生成：

1. **Struct 定义：**
```moonbit
pub(all) struct {MessageName} {
  {field_name} : {MoonBitType}
  ...
}
```

2. **类型映射：**

| Proto Type | MoonBit Type | 默认值 |
|---|---|---|
| double | Double | 0.0 |
| float | Float | 0.0 |
| int32/sint32/sfixed32 | Int | 0 |
| int64/sint64/sfixed64 | Int64 | 0L |
| uint32/fixed32 | UInt | 0U |
| uint64/fixed64 | UInt64 | 0UL |
| bool | Bool | false |
| string | String | "" |
| bytes | Array[Byte] | [] |
| message T | T? | None |
| repeated T | Array[T] | [] |

3. **encode 方法：**
```moonbit
pub fn {MessageName}::encode(self : {MessageName}) -> Array[Byte] {
  let encoder = @wire.Encoder::new()
  if self.{field} != {default} {
    encoder.write_{type}({number}, self.{field})
  }
  ...
  encoder.finish()
}
```

4. **decode 方法：**
```moonbit
pub fn {MessageName}::decode(data : Array[Byte]) -> {MessageName} raise @wire.WireError {
  let decoder = @wire.Decoder::new(data)
  let mut {field} = {default}
  ...
  while decoder.is_at_end().not() {
    let tag = decoder.read_tag()
    match tag.field_number {
      {number} => {field} = decoder.read_{type}()
      ...
      _ => decoder.skip_field(tag.wire_type)
    }
  }
  { {field}, ... }
}
```

5. **new 构造函数（默认值）：**
```moonbit
pub fn {MessageName}::new() -> {MessageName} {
  { field1: default1, field2: default2, ... }
}
```

**公开 API：**
```
pub fn generate(file: @proto_parser.ProtoFile) -> String
pub fn generate_message(msg: @proto_parser.MessageDef) -> String
pub fn generate_enum(e: @proto_parser.EnumDef) -> String
```

---

## 6. cmd/main 规范

**功能：** CLI 工具，将 `.proto` 文件编译为 MoonBit 源代码

**用法：**
```
moon run cmd/main -- input.proto
```

**流程：**
1. 读取命令行参数获取 `.proto` 文件路径
2. 读取文件内容
3. 调用 `@proto_parser.parse(content)` 解析为 AST
4. 调用 `@codegen.generate(ast)` 生成 MoonBit 代码
5. 输出到 stdout

---

## 7. 测试策略

### 7.1 单元测试

| 包 | 测试文件 | 覆盖范围 |
|---|---|---|
| wire | varint_test.mbt | varint/zigzag 编解码边界值 |
| wire | encoder_test.mbt | 每种标量类型的编码正确性 |
| wire | decoder_test.mbt | 每种标量类型的解码正确性 |
| wire | nested_test.mbt | 嵌套 message、repeated/packed |
| proto_parser | lexer_test.mbt | token 识别、注释跳过、错误报告 |
| proto_parser | parser_test.mbt | 完整 proto 文件解析 |
| codegen | generator_test.mbt | 生成代码的正确性 |

### 7.2 集成测试

- **已知二进制数据验证：** 使用 Python/Go protobuf 库生成已知结构的二进制编码，在 MoonBit 中解码验证
- **往返测试（roundtrip）：** encode → decode 后值不变
- **跨类型组合测试：** 包含所有字段类型的复杂 message
- **前向兼容测试：** 解码器遇到未知字段能正确跳过

### 7.3 测试数据样例

```proto
syntax = "proto3";
package test;

message Person {
  string name = 1;
  int32 age = 2;
  repeated string tags = 3;
  Address address = 4;
}

message Address {
  string street = 1;
  string city = 2;
  int32 zip = 3;
}
```

---

## 8. 已知限制（MVP 范围外）

以下特性在本期不实现：
- `oneof` 字段
- `map` 字段
- `import` 语句（跨文件引用）
- `service` / gRPC 定义
- `extensions` / `any` 类型
- Well-known types（Timestamp, Duration 等）
- 自定义 option
- Proto2 语法支持

---

## 9. 兼容性目标

- **Wire format 兼容：** 与官方 protobuf 实现（Python/Go/C++）编码的二进制数据互通
- **Proto3 语法兼容：** 支持 proto3 核心子集（message、enum、scalar、repeated、nested）
- **MoonBit 目标后端：** wasm-gc（默认），兼顾 native 后端
