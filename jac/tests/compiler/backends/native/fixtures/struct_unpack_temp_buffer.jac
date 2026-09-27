"""struct.unpack over a temporary slice, the way binary parsers read fields:
each call's slice is released after decoding. MODE picks the form."""
import struct;
import os;

def u16_at(data: bytes, p: int) -> int {
    return int(struct.unpack("<H", data[p:p + 2])[0]);
}

def f32_at(data: bytes, p: int) -> float {
    return float(struct.unpack("<f", data[p:p + 4])[0]);
}

def u16_from(data: bytes, p: int) -> int {
    return int(struct.unpack_from("<H", data[p:p + 8], 2)[0]);
}

def u16_bytearray(data: bytes, p: int) -> int {
    return int(struct.unpack("<H", bytearray(data[p:p + 2]))[0]);
}

with entry {
    data = bytes([1, 2, 3, 4] * 64);
    mode = os.getenv("MODE", "u16");
    total = 0;
    for i in range(3000000) {
        p = (i * 4) % 240;
        if mode == "u16" {
            total += u16_at(data, p);
        } elif mode == "f32" {
            total += int(f32_at(data, p) * 0.0) + 1;
        } elif mode == "from" {
            total += u16_from(data, p);
        } else {
            total += u16_bytearray(data, p);
        }
    }
    print(mode, total);
}
