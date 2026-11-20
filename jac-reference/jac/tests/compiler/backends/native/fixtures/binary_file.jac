"""Binary file read returns a length-aware `bytes` buffer (#6404).

`open(path, "rb").read()` must return *all* bytes — including embedded NULs —
typed as `bytes`, so a binary parser can slice it and feed it to `struct`.
The text-mode `open(path, "r").read()` still returns `str` (sv-congruent).
"""

import struct;

def read_len(path: str) -> int {
    f = open(path, "rb");
    d = f.read();
    f.close();
    return len(d);
}

def byte_after_nul(path: str) -> int {
    f = open(path, "rb");
    d = f.read();
    f.close();
    return d[5];
}

def struct_from_file(path: str) -> int {
    f = open(path, "rb");
    d = f.read();
    f.close();
    return struct.unpack("<I", d[0:4])[0];
}

def read_with_ctx(path: str) -> int {
    total = 0;
    with open(path, "rb") as f {
        d = f.read();
        total = len(d);
    }
    return total;
}

def first_line_len(path: str) -> int {
    f = open(path, "rb");
    line = f.readline();
    f.close();
    return len(line);
}

def first_line_byte_after_nul(path: str) -> int {
    f = open(path, "rb");
    line = f.readline();
    f.close();
    return line[3];
}
