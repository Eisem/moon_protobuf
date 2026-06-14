///|
pub(all) enum TokenKind {
  Syntax
  Message
  Enum
  Repeated
  Optional
  Reserved
  Package
  Import
  Oneof
  Map
  TDouble
  TFloat
  TInt32
  TInt64
  TUint32
  TUint64
  TSint32
  TSint64
  TFixed32
  TFixed64
  TSfixed32
  TSfixed64
  TBool
  TString
  TBytes
  Ident(String)
  IntLit(Int)
  StringLit(String)
  LBrace
  RBrace
  LBracket
  RBracket
  Semicolon
  Equals
  Comma
  Dot
  Eof
} derive(Debug, Eq)

///|
pub(all) struct Token {
  kind : TokenKind
  line : Int
  col : Int
} derive(Debug, Eq)

///|
pub(all) suberror ParseError {
  UnexpectedChar(char~ : Char, line~ : Int, col~ : Int)
  UnterminatedString(line~ : Int, col~ : Int)
  UnexpectedToken(expected~ : String, got~ : String, line~ : Int, col~ : Int)
  UnexpectedEof(expected~ : String)
  InvalidSyntax(message~ : String, line~ : Int, col~ : Int)
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  match self {
    Syntax => logger.write_string("syntax")
    Message => logger.write_string("message")
    Enum => logger.write_string("enum")
    Repeated => logger.write_string("repeated")
    Optional => logger.write_string("optional")
    Reserved => logger.write_string("reserved")
    Package => logger.write_string("package")
    Import => logger.write_string("import")
    Oneof => logger.write_string("oneof")
    Map => logger.write_string("map")
    TDouble => logger.write_string("double")
    TFloat => logger.write_string("float")
    TInt32 => logger.write_string("int32")
    TInt64 => logger.write_string("int64")
    TUint32 => logger.write_string("uint32")
    TUint64 => logger.write_string("uint64")
    TSint32 => logger.write_string("sint32")
    TSint64 => logger.write_string("sint64")
    TFixed32 => logger.write_string("fixed32")
    TFixed64 => logger.write_string("fixed64")
    TSfixed32 => logger.write_string("sfixed32")
    TSfixed64 => logger.write_string("sfixed64")
    TBool => logger.write_string("bool")
    TString => logger.write_string("string")
    TBytes => logger.write_string("bytes")
    Ident(s) => logger.write_string("ident(\{s})")
    IntLit(n) => logger.write_string("int(\{n})")
    StringLit(s) => logger.write_string("string(\{s})")
    LBrace => logger.write_string("{")
    RBrace => logger.write_string("}")
    LBracket => logger.write_string("[")
    RBracket => logger.write_string("]")
    Semicolon => logger.write_string(";")
    Equals => logger.write_string("=")
    Comma => logger.write_string(",")
    Dot => logger.write_string(".")
    Eof => logger.write_string("EOF")
  }
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    UnexpectedChar(char~, line~, col~) =>
      logger.write_string("unexpected char '\{char}' at \{line}:\{col}")
    UnterminatedString(line~, col~) =>
      logger.write_string("unterminated string at \{line}:\{col}")
    UnexpectedToken(expected~, got~, line~, col~) =>
      logger.write_string("expected \{expected}, got \{got} at \{line}:\{col}")
    UnexpectedEof(expected~) =>
      logger.write_string("unexpected EOF, expected \{expected}")
    InvalidSyntax(message~, line~, col~) =>
      logger.write_string("\{message} at \{line}:\{col}")
  }
}

///|
struct Lexer {
  input : String
  mut pos : Int
  mut line : Int
  mut col : Int
}

///|
pub fn Lexer::new(input : String) -> Lexer {
  { input, pos: 0, line: 1, col: 1 }
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos >= self.input.length() {
    '\u0000'
  } else {
    match self.input.get_char(self.pos) {
      Some(c) => c
      None => '\u0000'
    }
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  if c == '\n' {
    self.line = self.line + 1
    self.col = 1
  } else {
    self.col = self.col + 1
  }
  self.pos = self.pos + 1
  c
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while self.pos < self.input.length() {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      let _ = self.advance()
    } else {
      break
    }
  }
}

///|
fn Lexer::skip_line_comment(self : Lexer) -> Unit {
  while self.pos < self.input.length() && self.peek() != '\n' {
    let _ = self.advance()
  }
}

///|
fn Lexer::skip_block_comment(self : Lexer) -> Unit {
  while self.pos < self.input.length() {
    let c = self.advance()
    if c == '*' && self.peek() == '/' {
      let _ = self.advance()
      return
    }
  }
}

///|
fn Lexer::read_ident(self : Lexer) -> String {
  let start = self.pos
  while self.pos < self.input.length() {
    let c = self.peek()
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      let _ = self.advance()
    } else {
      break
    }
  }
  self.input[start:self.pos].to_owned()
}

///|
fn Lexer::read_number(self : Lexer) -> Int {
  let mut result = 0
  while self.pos < self.input.length() {
    let c = self.peek()
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      let _ = self.advance()
    } else {
      break
    }
  }
  result
}

///|
fn Lexer::read_string_lit(
  self : Lexer,
  quote : Char,
) -> String raise ParseError {
  let buf = StringBuilder::new()
  while self.pos < self.input.length() {
    let c = self.advance()
    if c == quote {
      return buf.to_string()
    }
    if c == '\\' {
      let escaped = self.advance()
      match escaped {
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        '\\' => buf.write_char('\\')
        '\'' => buf.write_char('\'')
        '"' => buf.write_char('"')
        _ => {
          buf.write_char('\\')
          buf.write_char(escaped)
        }
      }
    } else {
      buf.write_char(c)
    }
  }
  raise ParseError::UnterminatedString(line=self.line, col=self.col)
}

///|
fn keyword_or_ident(word : String) -> TokenKind {
  match word {
    "syntax" => Syntax
    "message" => Message
    "enum" => Enum
    "repeated" => Repeated
    "optional" => Optional
    "reserved" => Reserved
    "package" => Package
    "import" => Import
    "oneof" => Oneof
    "map" => Map
    "double" => TDouble
    "float" => TFloat
    "int32" => TInt32
    "int64" => TInt64
    "uint32" => TUint32
    "uint64" => TUint64
    "sint32" => TSint32
    "sint64" => TSint64
    "fixed32" => TFixed32
    "fixed64" => TFixed64
    "sfixed32" => TSfixed32
    "sfixed64" => TSfixed64
    "bool" => TBool
    "string" => TString
    "bytes" => TBytes
    _ => Ident(word)
  }
}

///|
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] raise ParseError {
  let tokens : Array[Token] = []
  while self.pos < self.input.length() {
    self.skip_whitespace()
    if self.pos >= self.input.length() {
      break
    }
    let start_line = self.line
    let start_col = self.col
    let c = self.peek()
    if c == '/' {
      let _ = self.advance()
      if self.peek() == '/' {
        let _ = self.advance()
        self.skip_line_comment()
        continue
      } else if self.peek() == '*' {
        let _ = self.advance()
        self.skip_block_comment()
        continue
      } else {
        raise ParseError::UnexpectedChar(
          char='/',
          line=start_line,
          col=start_col,
        )
      }
    }
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' {
      let word = self.read_ident()
      tokens.push({
        kind: keyword_or_ident(word),
        line: start_line,
        col: start_col,
      })
    } else if c >= '0' && c <= '9' {
      let num = self.read_number()
      tokens.push({ kind: IntLit(num), line: start_line, col: start_col })
    } else if c == '"' || c == '\'' {
      let _ = self.advance()
      let s = self.read_string_lit(c)
      tokens.push({ kind: StringLit(s), line: start_line, col: start_col })
    } else if c == '{' {
      let _ = self.advance()
      tokens.push({ kind: LBrace, line: start_line, col: start_col })
    } else if c == '}' {
      let _ = self.advance()
      tokens.push({ kind: RBrace, line: start_line, col: start_col })
    } else if c == '[' {
      let _ = self.advance()
      tokens.push({ kind: LBracket, line: start_line, col: start_col })
    } else if c == ']' {
      let _ = self.advance()
      tokens.push({ kind: RBracket, line: start_line, col: start_col })
    } else if c == ';' {
      let _ = self.advance()
      tokens.push({ kind: Semicolon, line: start_line, col: start_col })
    } else if c == '=' {
      let _ = self.advance()
      tokens.push({ kind: Equals, line: start_line, col: start_col })
    } else if c == ',' {
      let _ = self.advance()
      tokens.push({ kind: Comma, line: start_line, col: start_col })
    } else if c == '.' {
      let _ = self.advance()
      tokens.push({ kind: Dot, line: start_line, col: start_col })
    } else {
      let _ = self.advance()
      raise ParseError::UnexpectedChar(char=c, line=start_line, col=start_col)
    }
  }
  tokens.push({ kind: Eof, line: self.line, col: self.col })
  tokens
}
