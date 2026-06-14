///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
}

///|
pub fn parse(input : String) -> ProtoFile raise ParseError {
  let lexer = Lexer::new(input)
  let tokens = lexer.tokenize()
  let parser : Parser = { tokens, pos: 0 }
  parser.parse_file()
}

///|
fn Parser::current(self : Parser) -> Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    { kind: Eof, line: 0, col: 0 }
  }
}

///|
fn Parser::advance_token(self : Parser) -> Token {
  let tok = self.current()
  self.pos = self.pos + 1
  tok
}

///|
fn Parser::expect(
  self : Parser,
  expected : TokenKind,
) -> Token raise ParseError {
  let tok = self.current()
  if tok.kind == expected {
    self.pos = self.pos + 1
    tok
  } else {
    raise ParseError::UnexpectedToken(
      expected="\{expected}",
      got="\{tok.kind}",
      line=tok.line,
      col=tok.col,
    )
  }
}

///|
fn Parser::expect_semicolon(self : Parser) -> Unit raise ParseError {
  let _ = self.expect(Semicolon)
}

///|
fn Parser::expect_ident(self : Parser) -> String raise ParseError {
  let tok = self.current()
  match tok.kind {
    Ident(name) => {
      self.pos = self.pos + 1
      name
    }
    _ =>
      raise ParseError::UnexpectedToken(
        expected="identifier",
        got="\{tok.kind}",
        line=tok.line,
        col=tok.col,
      )
  }
}

///|
fn Parser::expect_int(self : Parser) -> Int raise ParseError {
  let tok = self.current()
  match tok.kind {
    IntLit(n) => {
      self.pos = self.pos + 1
      n
    }
    _ =>
      raise ParseError::UnexpectedToken(
        expected="integer",
        got="\{tok.kind}",
        line=tok.line,
        col=tok.col,
      )
  }
}

///|
fn Parser::expect_string_lit(self : Parser) -> String raise ParseError {
  let tok = self.current()
  match tok.kind {
    StringLit(s) => {
      self.pos = self.pos + 1
      s
    }
    _ =>
      raise ParseError::UnexpectedToken(
        expected="string literal",
        got="\{tok.kind}",
        line=tok.line,
        col=tok.col,
      )
  }
}

///|
fn Parser::parse_file(self : Parser) -> ProtoFile raise ParseError {
  let mut syntax = "proto3"
  let mut package_name = ""
  let messages : Array[MessageDef] = []
  let enums : Array[EnumDef] = []
  while self.current().kind != Eof {
    match self.current().kind {
      Syntax => {
        self.pos = self.pos + 1
        let _ = self.expect(Equals)
        syntax = self.expect_string_lit()
        self.expect_semicolon()
      }
      Package => {
        self.pos = self.pos + 1
        let buf = StringBuilder::new()
        buf.write_string(self.expect_ident())
        while self.current().kind == Dot {
          self.pos = self.pos + 1
          buf.write_char('.')
          buf.write_string(self.expect_ident())
        }
        package_name = buf.to_string()
        self.expect_semicolon()
      }
      Message => messages.push(self.parse_message())
      Enum => enums.push(self.parse_enum())
      Import => {
        self.pos = self.pos + 1
        let _ = self.expect_string_lit()
        self.expect_semicolon()
      }
      _ => {
        let tok = self.advance_token()
        raise ParseError::InvalidSyntax(
          message="unexpected top-level token: \{tok.kind}",
          line=tok.line,
          col=tok.col,
        )
      }
    }
  }
  { syntax, package_name, messages, enums }
}

///|
fn Parser::parse_message(self : Parser) -> MessageDef raise ParseError {
  let _ = self.expect(Message)
  let name = self.expect_ident()
  let _ = self.expect(LBrace)
  let fields : Array[FieldDef] = []
  let oneofs : Array[OneofDef] = []
  let nested_messages : Array[MessageDef] = []
  let nested_enums : Array[EnumDef] = []
  while self.current().kind != RBrace && self.current().kind != Eof {
    match self.current().kind {
      Message => nested_messages.push(self.parse_message())
      Enum => nested_enums.push(self.parse_enum())
      Oneof => oneofs.push(self.parse_oneof())
      Reserved => {
        self.pos = self.pos + 1
        while self.current().kind != Semicolon && self.current().kind != Eof {
          self.pos = self.pos + 1
        }
        self.expect_semicolon()
      }
      _ => fields.push(self.parse_field())
    }
  }
  let _ = self.expect(RBrace)
  { name, fields, oneofs, nested_messages, nested_enums }
}

///|
fn Parser::parse_oneof(self : Parser) -> OneofDef raise ParseError {
  let _ = self.expect(Oneof)
  let name = self.expect_ident()
  let _ = self.expect(LBrace)
  let fields : Array[OneofFieldDef] = []
  while self.current().kind != RBrace && self.current().kind != Eof {
    let field_type = self.parse_field_type()
    let field_name = self.expect_ident()
    let _ = self.expect(Equals)
    let number = self.expect_int()
    self.expect_semicolon()
    fields.push({ name: field_name, field_type, number })
  }
  let _ = self.expect(RBrace)
  { name, fields }
}

///|
fn Parser::parse_field(self : Parser) -> FieldDef raise ParseError {
  let mut label : FieldLabel = Optional
  match self.current().kind {
    Map => {
      self.pos = self.pos + 1
      let _ = self.expect(LAngle)
      let key_type = self.parse_scalar_type()
      let _ = self.expect(Comma)
      let value_type = self.parse_field_type()
      let _ = self.expect(RAngle)
      let name = self.expect_ident()
      let _ = self.expect(Equals)
      let number = self.expect_int()
      self.expect_semicolon()
      return { name, field_type: MapType(key_type~, value_type~), label: Optional, number }
    }
    Repeated => {
      label = Repeated
      self.pos = self.pos + 1
    }
    Optional => {
      label = Optional
      self.pos = self.pos + 1
    }
    _ => ()
  }
  let field_type = self.parse_field_type()
  let name = self.expect_ident()
  let _ = self.expect(Equals)
  let number = self.expect_int()
  self.expect_semicolon()
  { name, field_type, label, number }
}

///|
fn Parser::parse_scalar_type(self : Parser) -> ScalarType raise ParseError {
  let tok = self.current()
  match tok.kind {
    TDouble => { self.pos = self.pos + 1; Double }
    TFloat => { self.pos = self.pos + 1; Float }
    TInt32 => { self.pos = self.pos + 1; Int32 }
    TInt64 => { self.pos = self.pos + 1; Int64 }
    TUint32 => { self.pos = self.pos + 1; UInt32 }
    TUint64 => { self.pos = self.pos + 1; UInt64 }
    TSint32 => { self.pos = self.pos + 1; SInt32 }
    TSint64 => { self.pos = self.pos + 1; SInt64 }
    TFixed32 => { self.pos = self.pos + 1; Fixed32 }
    TFixed64 => { self.pos = self.pos + 1; Fixed64 }
    TSfixed32 => { self.pos = self.pos + 1; SFixed32 }
    TSfixed64 => { self.pos = self.pos + 1; SFixed64 }
    TBool => { self.pos = self.pos + 1; Bool }
    TString => { self.pos = self.pos + 1; String_ }
    TBytes => { self.pos = self.pos + 1; Bytes }
    _ =>
      raise ParseError::UnexpectedToken(
        expected="scalar type",
        got="\{tok.kind}",
        line=tok.line,
        col=tok.col,
      )
  }
}

///|
fn Parser::parse_field_type(self : Parser) -> FieldType raise ParseError {
  let tok = self.current()
  match tok.kind {
    TDouble => {
      self.pos = self.pos + 1
      Scalar(Double)
    }
    TFloat => {
      self.pos = self.pos + 1
      Scalar(Float)
    }
    TInt32 => {
      self.pos = self.pos + 1
      Scalar(Int32)
    }
    TInt64 => {
      self.pos = self.pos + 1
      Scalar(Int64)
    }
    TUint32 => {
      self.pos = self.pos + 1
      Scalar(UInt32)
    }
    TUint64 => {
      self.pos = self.pos + 1
      Scalar(UInt64)
    }
    TSint32 => {
      self.pos = self.pos + 1
      Scalar(SInt32)
    }
    TSint64 => {
      self.pos = self.pos + 1
      Scalar(SInt64)
    }
    TFixed32 => {
      self.pos = self.pos + 1
      Scalar(Fixed32)
    }
    TFixed64 => {
      self.pos = self.pos + 1
      Scalar(Fixed64)
    }
    TSfixed32 => {
      self.pos = self.pos + 1
      Scalar(SFixed32)
    }
    TSfixed64 => {
      self.pos = self.pos + 1
      Scalar(SFixed64)
    }
    TBool => {
      self.pos = self.pos + 1
      Scalar(Bool)
    }
    TString => {
      self.pos = self.pos + 1
      Scalar(String_)
    }
    TBytes => {
      self.pos = self.pos + 1
      Scalar(Bytes)
    }
    Ident(name) => {
      self.pos = self.pos + 1
      Message(name)
    }
    _ =>
      raise ParseError::UnexpectedToken(
        expected="type",
        got="\{tok.kind}",
        line=tok.line,
        col=tok.col,
      )
  }
}

///|
fn Parser::parse_enum(self : Parser) -> EnumDef raise ParseError {
  let _ = self.expect(Enum)
  let name = self.expect_ident()
  let _ = self.expect(LBrace)
  let values : Array[EnumValueDef] = []
  while self.current().kind != RBrace && self.current().kind != Eof {
    let value_name = self.expect_ident()
    let _ = self.expect(Equals)
    let number = self.expect_int()
    self.expect_semicolon()
    values.push({ name: value_name, number })
  }
  let _ = self.expect(RBrace)
  { name, values }
}
