///|
test "generate simple message" {
  let file : @proto_parser.ProtoFile = {
    syntax: "proto3",
    package_name: "test",
    messages: [
      {
        name: "Person",
        fields: [
          {
            name: "name",
            field_type: Scalar(String_),
            label: Optional,
            number: 1,
          },
          { name: "age", field_type: Scalar(Int32), label: Optional, number: 2 },
        ],
        nested_messages: [],
        nested_enums: [],
      },
    ],
    enums: [],
  }
  let output = @codegen.generate(file)
  assert_true(output.contains("pub(all) struct Person"))
  assert_true(output.contains("name : String"))
  assert_true(output.contains("age : Int"))
  assert_true(output.contains("Person::new()"))
  assert_true(output.contains("Person::encode"))
  assert_true(output.contains("Person::decode"))
}

///|
test "generate enum" {
  let file : @proto_parser.ProtoFile = {
    syntax: "proto3",
    package_name: "",
    messages: [],
    enums: [
      {
        name: "Status",
        values: [{ name: "UNKNOWN", number: 0 }, { name: "ACTIVE", number: 1 }],
      },
    ],
  }
  let output = @codegen.generate(file)
  assert_true(output.contains("pub(all) enum Status"))
  assert_true(output.contains("UNKNOWN"))
  assert_true(output.contains("ACTIVE"))
  assert_true(output.contains("Status::to_int"))
  assert_true(output.contains("Status::from_int"))
}

///|
test "generate repeated field" {
  let file : @proto_parser.ProtoFile = {
    syntax: "proto3",
    package_name: "",
    messages: [
      {
        name: "List",
        fields: [
          {
            name: "values",
            field_type: Scalar(Int32),
            label: Repeated,
            number: 1,
          },
          {
            name: "names",
            field_type: Scalar(String_),
            label: Repeated,
            number: 2,
          },
        ],
        nested_messages: [],
        nested_enums: [],
      },
    ],
    enums: [],
  }
  let output = @codegen.generate(file)
  assert_true(output.contains("values : Array[Int]"))
  assert_true(output.contains("names : Array[String]"))
  assert_true(output.contains("write_packed_int32"))
}

///|
test "generate map field" {
  let file : @proto_parser.ProtoFile = {
    syntax: "proto3",
    package_name: "",
    messages: [
      {
        name: "Config",
        fields: [
          {
            name: "metadata",
            field_type: MapType(key_type=String_, value_type=Scalar(String_)),
            label: Optional,
            number: 1,
          },
        ],
        nested_messages: [],
        nested_enums: [],
      },
    ],
    enums: [],
  }
  let output = @codegen.generate(file)
  assert_true(output.contains("metadata : Map[String, String]"))
  assert_true(output.contains("for k, v in self.metadata"))
  assert_true(output.contains("write_message"))
  assert_true(output.contains("_entry_dec"))
}

///|
test "generate message field" {
  let file : @proto_parser.ProtoFile = {
    syntax: "proto3",
    package_name: "",
    messages: [
      {
        name: "Wrapper",
        fields: [
          {
            name: "inner",
            field_type: Message("Inner"),
            label: Optional,
            number: 1,
          },
        ],
        nested_messages: [],
        nested_enums: [],
      },
    ],
    enums: [],
  }
  let output = @codegen.generate(file)
  assert_true(output.contains("inner : Inner?"))
  assert_true(output.contains("None"))
}
