///|
test "tokenize simple message" {
  let input =
    #|syntax = "proto3";
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|}
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_true(tokens[0].kind == Syntax)
  assert_true(tokens[1].kind == Equals)
  assert_true(tokens[2].kind == StringLit("proto3"))
  assert_true(tokens[3].kind == Semicolon)
  assert_true(tokens[4].kind == Message)
  assert_true(tokens[5].kind == Ident("Person"))
  assert_true(tokens[6].kind == LBrace)
  assert_true(tokens[7].kind == TString)
  assert_true(tokens[8].kind == Ident("name"))
  assert_true(tokens[9].kind == Equals)
  assert_true(tokens[10].kind == IntLit(1))
  assert_true(tokens[11].kind == Semicolon)
}

///|
test "tokenize with comments" {
  let input =
    #|// This is a comment
    #|message Foo {
    #|  /* block comment */
    #|  int32 bar = 1;
    #|}
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_true(tokens[0].kind == Message)
  assert_true(tokens[1].kind == Ident("Foo"))
  assert_true(tokens[2].kind == LBrace)
  assert_true(tokens[3].kind == TInt32)
  assert_true(tokens[4].kind == Ident("bar"))
}

///|
test "tokenize all scalar types" {
  let input = "double float int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64 bool string bytes"
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_true(tokens[0].kind == TDouble)
  assert_true(tokens[1].kind == TFloat)
  assert_true(tokens[2].kind == TInt32)
  assert_true(tokens[3].kind == TInt64)
  assert_true(tokens[4].kind == TUint32)
  assert_true(tokens[5].kind == TUint64)
  assert_true(tokens[6].kind == TSint32)
  assert_true(tokens[7].kind == TSint64)
  assert_true(tokens[8].kind == TFixed32)
  assert_true(tokens[9].kind == TFixed64)
  assert_true(tokens[10].kind == TSfixed32)
  assert_true(tokens[11].kind == TSfixed64)
  assert_true(tokens[12].kind == TBool)
  assert_true(tokens[13].kind == TString)
  assert_true(tokens[14].kind == TBytes)
}

///|
test "tokenize enum" {
  let input =
    #|enum Status {
    #|  UNKNOWN = 0;
    #|  ACTIVE = 1;
    #|}
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_true(tokens[0].kind == Enum)
  assert_true(tokens[1].kind == Ident("Status"))
  assert_true(tokens[2].kind == LBrace)
  assert_true(tokens[3].kind == Ident("UNKNOWN"))
  assert_true(tokens[4].kind == Equals)
  assert_true(tokens[5].kind == IntLit(0))
  assert_true(tokens[6].kind == Semicolon)
}

///|
test "tokenize repeated and package" {
  let input =
    #|package test.example;
    #|message List {
    #|  repeated int32 values = 1;
    #|}
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_true(tokens[0].kind == Package)
  assert_true(tokens[1].kind == Ident("test"))
  assert_true(tokens[2].kind == Dot)
  assert_true(tokens[3].kind == Ident("example"))
  assert_true(tokens[4].kind == Semicolon)
  assert_true(tokens[5].kind == Message)
  assert_true(tokens[8].kind == Repeated)
}

///|
test "line and column tracking" {
  let input =
    #|syntax = "proto3";
    #|message Foo {
    #|}
  let lexer = @proto_parser.Lexer::new(input)
  let tokens = lexer.tokenize()
  assert_eq(tokens[0].line, 1)
  assert_eq(tokens[0].col, 1)
  assert_eq(tokens[4].line, 2)
}
