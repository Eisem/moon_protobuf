///|
test "parse simple message" {
  let input =
    #|syntax = "proto3";
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.syntax, "proto3")
  assert_eq(file.messages.length(), 1)
  assert_eq(file.messages[0].name, "Person")
  assert_eq(file.messages[0].fields.length(), 2)
  assert_eq(file.messages[0].fields[0].name, "name")
  assert_true(file.messages[0].fields[0].field_type == Scalar(String_))
  assert_eq(file.messages[0].fields[0].number, 1)
  assert_eq(file.messages[0].fields[1].name, "age")
  assert_true(file.messages[0].fields[1].field_type == Scalar(Int32))
  assert_eq(file.messages[0].fields[1].number, 2)
}

///|
test "parse with package" {
  let input =
    #|syntax = "proto3";
    #|package example.proto;
    #|message Empty {}
  let file = @proto_parser.parse(input)
  assert_eq(file.package_name, "example.proto")
  assert_eq(file.messages.length(), 1)
  assert_eq(file.messages[0].name, "Empty")
}

///|
test "parse enum" {
  let input =
    #|syntax = "proto3";
    #|enum Status {
    #|  UNKNOWN = 0;
    #|  ACTIVE = 1;
    #|  INACTIVE = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.enums.length(), 1)
  assert_eq(file.enums[0].name, "Status")
  assert_eq(file.enums[0].values.length(), 3)
  assert_eq(file.enums[0].values[0].name, "UNKNOWN")
  assert_eq(file.enums[0].values[0].number, 0)
  assert_eq(file.enums[0].values[2].name, "INACTIVE")
}

///|
test "parse repeated fields" {
  let input =
    #|syntax = "proto3";
    #|message List {
    #|  repeated int32 values = 1;
    #|  repeated string names = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.messages[0].fields[0].name, "values")
  assert_true(file.messages[0].fields[0].label == Repeated)
  assert_true(file.messages[0].fields[0].field_type == Scalar(Int32))
  assert_true(file.messages[0].fields[1].label == Repeated)
}

///|
test "parse nested message" {
  let input =
    #|syntax = "proto3";
    #|message Outer {
    #|  string name = 1;
    #|  message Inner {
    #|    int32 value = 1;
    #|  }
    #|  Inner inner = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.messages[0].name, "Outer")
  assert_eq(file.messages[0].nested_messages.length(), 1)
  assert_eq(file.messages[0].nested_messages[0].name, "Inner")
  assert_eq(file.messages[0].nested_messages[0].fields[0].name, "value")
  assert_true(file.messages[0].fields[1].field_type == Message("Inner"))
}

///|
test "parse all scalar types" {
  let input =
    #|syntax = "proto3";
    #|message AllTypes {
    #|  double f1 = 1;
    #|  float f2 = 2;
    #|  int32 f3 = 3;
    #|  int64 f4 = 4;
    #|  uint32 f5 = 5;
    #|  uint64 f6 = 6;
    #|  sint32 f7 = 7;
    #|  sint64 f8 = 8;
    #|  fixed32 f9 = 9;
    #|  fixed64 f10 = 10;
    #|  sfixed32 f11 = 11;
    #|  sfixed64 f12 = 12;
    #|  bool f13 = 13;
    #|  string f14 = 14;
    #|  bytes f15 = 15;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.messages[0].fields.length(), 15)
  assert_true(file.messages[0].fields[0].field_type == Scalar(Double))
  assert_true(file.messages[0].fields[14].field_type == Scalar(Bytes))
}

///|
test "parse map field" {
  let input =
    #|syntax = "proto3";
    #|message Config {
    #|  map<string, string> metadata = 1;
    #|  map<int32, string> labels = 2;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.messages[0].name, "Config")
  assert_eq(file.messages[0].fields.length(), 2)
  assert_eq(file.messages[0].fields[0].name, "metadata")
  assert_true(
    file.messages[0].fields[0].field_type ==
    MapType(key_type=String_, value_type=Scalar(String_)),
  )
  assert_true(
    file.messages[0].fields[1].field_type ==
    MapType(key_type=Int32, value_type=Scalar(String_)),
  )
}

///|
test "parse oneof" {
  let input =
    #|syntax = "proto3";
    #|message Shape {
    #|  string name = 1;
    #|  oneof kind {
    #|    int32 circle_radius = 2;
    #|    string rect_size = 3;
    #|    double triangle_area = 4;
    #|  }
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.messages[0].name, "Shape")
  assert_eq(file.messages[0].fields.length(), 1)
  assert_eq(file.messages[0].oneofs.length(), 1)
  assert_eq(file.messages[0].oneofs[0].name, "kind")
  assert_eq(file.messages[0].oneofs[0].fields.length(), 3)
  assert_eq(file.messages[0].oneofs[0].fields[0].name, "circle_radius")
  assert_true(file.messages[0].oneofs[0].fields[0].field_type == Scalar(Int32))
  assert_eq(file.messages[0].oneofs[0].fields[0].number, 2)
}

///|
test "parse complex proto" {
  let input =
    #|syntax = "proto3";
    #|package test;
    #|
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|  repeated string tags = 3;
    #|  Address address = 4;
    #|}
    #|
    #|message Address {
    #|  string street = 1;
    #|  string city = 2;
    #|  int32 zip = 3;
    #|}
  let file = @proto_parser.parse(input)
  assert_eq(file.package_name, "test")
  assert_eq(file.messages.length(), 2)
  assert_eq(file.messages[0].name, "Person")
  assert_eq(file.messages[0].fields.length(), 4)
  assert_true(file.messages[0].fields[3].field_type == Message("Address"))
  assert_eq(file.messages[1].name, "Address")
  assert_eq(file.messages[1].fields.length(), 3)
}
