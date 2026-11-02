"""`struct.unpack` results bound to module-level names (entry globals).

The checker types `struct.unpack` as `tuple[Any, ...]`, so a module global
bound to it stores a boxed sequence, while the native call builds a tuple of
unboxed ints and floats. Each shape below read that tuple back through the
sequence layout and trapped, segfaulted or raised IndexError natively.
"""
import struct;

def first_word -> int {
    return int(words[0]);
}

with entry {
    words = struct.unpack("<H", bytes([7, 0]));
    print(words[0], first_word());
    packed = struct.pack("<fff", 1.0, 2.5, -3.0);
    vec = struct.unpack("<fff", packed);
    print(vec[0], vec[1], vec[2], len(vec));
    single = struct.unpack("<f", struct.pack("<f", 2.5));
    print(single[0]);
    pair = struct.unpack("<HH", bytes([7, 0, 8, 0]));
    alias = pair;
    print(alias[0], alias[1], pair[0] + pair[1]);
    signed = struct.unpack(">hi", bytes([255, 254, 0, 0, 1, 0]));
    print(signed[0], signed[1]);
    mixed = struct.unpack("<Hd", struct.pack("<Hd", 9, 0.5));
    print(mixed[0], mixed[1]);
    tail = struct.unpack_from("<H", bytes([0, 0, 5, 0]), 2);
    print(tail[0]);
    total = 0;
    for v in pair {
        total += int(v);
    }
    print(total);
    words = struct.unpack("<H", bytes([42, 1]));
    print(words[0], first_word());
}
