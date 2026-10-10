"""`sum` over bytes and bytearray adds the byte values, with CPython semantics."""

def total(data: &bytes) -> int {
    return sum(data);
}

def total_from(data: &bytes, start: int) -> int {
    return sum(data, start);
}

def mean(data: &bytes) -> float {
    return sum(data, 0.0) / len(data);
}

def checksum(data: &bytes) -> int {
    return sum(data[4:], sum(data[:4])) & 0xFFFF;
}

def array_total(data: &bytearray) -> int {
    return sum(data);
}

with entry {
    high = bytes([1, 2, 127, 128, 250, 255]);
    print(total(high), total_from(high, 1000), total_from(high, -763));
    print(total(b""), total_from(b"", 7), sum(b"\x00\x00"), sum(b"\xff" * 300));
    print(mean(high), sum(high, 0.5));
    print(checksum(bytes([7, 200, 9, 255, 31, 250])), sum(b"PK\x05\x06"));
    grow = bytearray([200, 200]);
    grow.append(255);
    print(
        array_total(grow), sum(grow, 1), sum(bytearray()), sum(bytearray(b"\x80"), 0.25)
    );
}
