///|
fn main {
  let proto_input =
    #|syntax = "proto3";
    #|package example;
    #|
    #|message Person {
    #|  string name = 1;
    #|  int32 age = 2;
    #|  repeated string tags = 3;
    #|}
  println("=== Proto Input ===")
  println(proto_input)
  println("\n=== Generated MoonBit Code ===")
  let file = try {
    @proto_parser.parse(proto_input)
  } catch {
    err => {
      println("Parse error: \{err}")
      return
    }
  }
  let generated = @codegen.generate(file)
  println(generated)
  println("=== Wire Format Demo ===")
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Alice")
  enc.write_int32(2, 30)
  enc.write_string(3, "developer")
  enc.write_string(3, "moonbit")
  let data = enc.finish()
  println("Encoded Person: \{data.length()} bytes")
  let dec = @wire.Decoder::new(data)
  let mut name = ""
  let mut age = 0
  let tags : Array[String] = []
  while !(dec.is_at_end()) {
    let tag = try { dec.read_tag() } catch { _ => break }
    match tag.field_number {
      1 => name = try { dec.read_string() } catch { _ => break }
      2 => age = try { dec.read_int32() } catch { _ => break }
      3 => {
        let s = try { dec.read_string() } catch { _ => break }
        tags.push(s)
      }
      _ => try { dec.skip_field(tag.wire_type) } catch { _ => break }
    }
  }
  println("Decoded: name=\{name}, age=\{age}, tags=\{to_repr(tags)}")
}
