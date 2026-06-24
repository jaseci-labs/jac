# Bug #BYTEARRAY-SLICE: assigning `bytes` to a `bytearray` slice fires E1001.
# Valid Python: bytearray slice assignment accepts bytes, bytearray, or Iterable[int].

def test {
    ELFMAG: bytes = b"\x7fELF";
    ident: bytearray = bytearray(16);
    ident[0:4] = ELFMAG;
    ident[4:8] = b"\x00\x01\x02\x03";
}
