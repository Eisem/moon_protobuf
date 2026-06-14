///|
fn main {
  let buf : Array[Byte] = []
  @wire.encode_varint(buf, 150UL)
  println("Encoded 150 as varint: \{buf.length()} bytes")
}
