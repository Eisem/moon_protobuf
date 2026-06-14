# moon_protobuf 项目申报书

## 基本信息

- **项目名称：** moon_protobuf：Protocol Buffers (proto3) 编解码库的 MoonBit 实现
- **参赛者：** [你的姓名]
- **联系方式：** [手机号]
- **GitHub 仓库链接：** https://github.com/Eisem/moon_protobuf
- **Gitlink 仓库链接：** [同步后填写]
- **项目方向：** 面向特定格式的（反）序列化工具 / 工程基础设施
- **是否为移植项目：** 是（参考实现，非直接翻译）

---

## 项目简介

moon_protobuf 为 MoonBit 生态提供完整的 Protocol Buffers (proto3) 序列化/反序列化能力，包括三大核心模块：

1. **Wire Format 编解码引擎** — 实现 protobuf 二进制 wire format 的底层编码器和解码器，支持全部 15 种 proto3 标量类型、嵌套 message、repeated 字段（packed encoding）以及前向兼容的字段跳过机制。
2. **Proto3 文件解析器** — 包含完整的词法分析器和语法分析器，能将 `.proto` 文件解析为结构化 AST，支持 message、enum、oneof、map、repeated、nested message 等 proto3 核心语法。
3. **MoonBit 代码生成器** — 从解析后的 AST 自动生成 MoonBit struct 定义、构造函数、encode/decode 方法，实现"写一次 .proto，自动获得类型安全的序列化代码"。

该项目填补了 MoonBit 生态中 **跨语言二进制序列化** 方向的空白。Protobuf 是微服务通信、数据交换领域的事实标准（被 gRPC、Google Cloud、Kubernetes 等广泛使用），moon_protobuf 使 MoonBit 程序能够与 Python、Go、Rust、Java 等语言编写的服务进行高效的二进制数据互通。

---

## 核心功能范围

- 完整的 Varint / ZigZag / Fixed32 / Fixed64 编解码算法
- 支持全部 proto3 标量类型：double, float, int32, int64, uint32, uint64, sint32, sint64, fixed32, fixed64, sfixed32, sfixed64, bool, string, bytes
- 嵌套 message 编解码（length-delimited）
- repeated 字段支持（packed encoding 和 non-packed）
- map 字段支持（`map<K, V>` 语法解析和编解码生成）
- oneof 字段支持（生成 MoonBit enum 类型）
- Proto3 文件词法分析器（支持注释跳过、关键字识别、字符串/数字字面量）
- Proto3 文件语法分析器（支持 syntax、package、message、enum、oneof、map、nested message、reserved）
- MoonBit 代码生成器（生成 struct 定义 + new 构造 + encode/decode 方法）
- 未知字段跳过（前向兼容）
- 71 个自动化测试，覆盖核心功能路径
- CLI 演示工具（展示完整 parse → codegen → encode/decode 流程）
- GitHub Actions CI（check + build + test + format）

---

## 移植或参考说明

- **参考项目：** Rust `prost` (https://github.com/tokio-rs/prost), Go `protobuf` (https://github.com/protocolbuffers/protobuf-go)
- **参考项目许可证：** Apache-2.0 (prost), BSD-3-Clause (protobuf-go)
- **本项目许可证：** Apache-2.0

与参考项目的关系说明：

本项目**不是**对任何现有实现的直接翻译或逐行移植。Wire format 编解码规则参照 Google 官方 Protocol Buffers 编码规范（https://protobuf.dev/programming-guides/encoding/），这是一个公开的技术标准。代码实现完全使用 MoonBit 的类型系统、错误处理和包管理机制重新设计，API 风格针对 MoonBit 生态做了适配优化。Proto 文件解析器和代码生成器均为原创实现。
