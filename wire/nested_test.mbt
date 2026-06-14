///|
test "deeply nested messages" {
  let enc = @wire.Encoder::new()
  enc.write_message(1, outer => {
    outer.write_string(1, "outer")
    outer.write_message(2, inner => {
      inner.write_int32(1, 99)
      inner.write_string(2, "inner")
    })
  })
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let mut outer_name = ""
  let mut inner_val = 0
  let mut inner_name = ""
  dec.read_message(outer_dec => {
    while !outer_dec.is_at_end() {
      let tag = outer_dec.read_tag()
      match tag.field_number {
        1 => outer_name = outer_dec.read_string()
        2 =>
          outer_dec.read_message(inner_dec => {
            while !inner_dec.is_at_end() {
              let itag = inner_dec.read_tag()
              match itag.field_number {
                1 => inner_val = inner_dec.read_int32()
                2 => inner_name = inner_dec.read_string()
                _ => inner_dec.skip_field(itag.wire_type)
              }
            }
          })
        _ => outer_dec.skip_field(tag.wire_type)
      }
    }
  })
  assert_eq(outer_name, "outer")
  assert_eq(inner_val, 99)
  assert_eq(inner_name, "inner")
}

///|
test "repeated strings (non-packed)" {
  let enc = @wire.Encoder::new()
  enc.write_string(3, "tag1")
  enc.write_string(3, "tag2")
  enc.write_string(3, "tag3")
  let dec = @wire.Decoder::new(enc.finish())
  let tags : Array[String] = []
  while !dec.is_at_end() {
    let tag = dec.read_tag()
    assert_true(tag.field_number == 3)
    tags.push(dec.read_string())
  }
  assert_eq(tags.length(), 3)
  assert_eq(tags[0], "tag1")
  assert_eq(tags[1], "tag2")
  assert_eq(tags[2], "tag3")
}

///|
test "packed uint64" {
  let enc = @wire.Encoder::new()
  enc.write_packed_uint64(1, [100UL, 200UL, 300UL, 18446744073709551615UL])
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let values = dec.read_packed_uint64()
  assert_eq(values.length(), 4)
  assert_eq(values[0], 100UL)
  assert_eq(values[1], 200UL)
  assert_eq(values[3], 18446744073709551615UL)
}

///|
test "packed double" {
  let enc = @wire.Encoder::new()
  enc.write_packed_double(1, [1.0, 2.5, 3.14])
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  let len = dec.read_uint64()
  assert_eq(len.reinterpret_as_int64().to_int(), 24)
  let v1 = dec.read_double()
  let v2 = dec.read_double()
  let v3 = dec.read_double()
  assert_eq(v1, 1.0)
  assert_eq(v2, 2.5)
  assert_true((v3 - 3.14).abs() < 0.0001)
}

///|
test "mixed fields with skip" {
  let enc = @wire.Encoder::new()
  enc.write_int32(1, 42)
  enc.write_fixed64(50, 0xFFUL)
  enc.write_string(2, "hello")
  enc.write_fixed32(51, 0xAAU)
  enc.write_bool(3, true)
  let dec = @wire.Decoder::new(enc.finish())
  let mut field1 = 0
  let mut field2 = ""
  let mut field3 = false
  while !dec.is_at_end() {
    let tag = dec.read_tag()
    match tag.field_number {
      1 => field1 = dec.read_int32()
      2 => field2 = dec.read_string()
      3 => field3 = dec.read_bool()
      _ => dec.skip_field(tag.wire_type)
    }
  }
  assert_eq(field1, 42)
  assert_eq(field2, "hello")
  assert_eq(field3, true)
}

///|
test "empty message" {
  let enc = @wire.Encoder::new()
  enc.write_message(1, _sub => ())
  let dec = @wire.Decoder::new(enc.finish())
  let _ = dec.read_tag()
  dec.read_message(_sub_dec => ())
  assert_true(dec.is_at_end())
}

///|
test "person-like message roundtrip" {
  let enc = @wire.Encoder::new()
  enc.write_string(1, "Alice")
  enc.write_int32(2, 30)
  enc.write_string(3, "developer")
  enc.write_string(3, "moonbit")
  enc.write_message(4, addr => {
    addr.write_string(1, "123 Main St")
    addr.write_string(2, "Shenzhen")
    addr.write_int32(3, 518000)
  })
  let data = enc.finish()
  let dec = @wire.Decoder::new(data)
  let mut name = ""
  let mut age = 0
  let tags : Array[String] = []
  let mut street = ""
  let mut city = ""
  let mut zip = 0
  while !dec.is_at_end() {
    let tag = dec.read_tag()
    match tag.field_number {
      1 => name = dec.read_string()
      2 => age = dec.read_int32()
      3 => tags.push(dec.read_string())
      4 =>
        dec.read_message(addr_dec => {
          while !addr_dec.is_at_end() {
            let atag = addr_dec.read_tag()
            match atag.field_number {
              1 => street = addr_dec.read_string()
              2 => city = addr_dec.read_string()
              3 => zip = addr_dec.read_int32()
              _ => addr_dec.skip_field(atag.wire_type)
            }
          }
        })
      _ => dec.skip_field(tag.wire_type)
    }
  }
  assert_eq(name, "Alice")
  assert_eq(age, 30)
  assert_eq(tags.length(), 2)
  assert_eq(tags[0], "developer")
  assert_eq(tags[1], "moonbit")
  assert_eq(street, "123 Main St")
  assert_eq(city, "Shenzhen")
  assert_eq(zip, 518000)
}
