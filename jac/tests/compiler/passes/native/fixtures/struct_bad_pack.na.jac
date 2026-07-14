"""struct.pack with the wrong argument count must be a compile-time error
(#6404): the format declares two fields but only one value is supplied, so
packing it would leave uninitialized tail bytes. CPython raises struct.error
at runtime; the native backend fails fast at compile time instead.
"""

import struct;

def bad_pack() -> int {
    p = struct.pack("<II", 1);
    return len(p);
}
