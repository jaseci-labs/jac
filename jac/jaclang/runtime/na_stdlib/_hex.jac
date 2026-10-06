def:pub to_hex(data: bytes) -> str {
    digits: bytes = b"0123456789abcdef";
    out: list[int] = [];
    n: int = len(data);
    i: int = 0;
    while i < n {
        v: int = data[i];
        out.append(digits[v >> 4]);
        out.append(digits[v & 15]);
        i += 1;
    }
    return bytes(out).decode();
}
