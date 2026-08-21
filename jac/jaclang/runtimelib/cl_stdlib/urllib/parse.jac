def _hex_byte(n: int) -> str {
    digits: str = "0123456789ABCDEF";
    hi: str = digits[(n // 16) % 16];
    lo: str = digits[n % 16];
    return hi + lo;
}


def:pub quote(text: str, safe: str = "/") -> str {
    out: str = "";
    for ch in text {
        o: int = ord(ch);
        if (
            (ch >= "a" and ch <= "z")
            or (ch >= "A" and ch <= "Z")
            or (ch >= "0" and ch <= "9")
            or ch in safe
            or ch in "-_.~"
        ) {
            out += ch;
        } else {
            out += "%" + _hex_byte(o);
        }
    }
    return out;
}
