"""Fixture for Bug #UNPACK-1: unpacking a non-tuple iterable in assignment."""

with entry {
    (b0, b1) = bytes([0x81, 0x7F]);
    ok_b: int = b0;
    bad_b: str = b1;       # Error: int not assignable to str

    (s0, s1) = "hi";
    ok_s: str = s0;
    bad_s: int = s1;       # Error: str not assignable to int

    (l0, l1) = [1, 2];
    ok_l: int = l0;
    bad_l: str = l1;       # Error: int not assignable to str
}
