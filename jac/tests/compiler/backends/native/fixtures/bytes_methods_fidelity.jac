"""bytes methods natively and in Python: hex, fromhex, case, strip, split,
replace and join, including the optional-argument shapes."""
def hexed(data: bytes) -> str {
    return data.hex();
}

def unhexed(text: str) -> bytes {
    return bytes.fromhex(text);
}

def unhex_error(text: str) -> str {
    try {
        unhexed(text);
    } except ValueError as e {
        return str(e);
    }
    return "no error";
}

def shown(parts: list[bytes]) -> str {
    out = "";
    for part in parts {
        out += "[" + part.hex() + "]";
    }
    return out;
}

def stripped(data: bytes, chars: (bytes | None)) -> str {
    return data.strip(chars).hex()
        + " "
        + data.lstrip(chars).hex()
        + " "
        + data.rstrip(chars).hex();
}

def split_by(data: bytes, sep: (bytes | None), maxsplit: int) -> str {
    return shown(data.split(sep, maxsplit));
}

with entry {
    print(hexed(b"\x00\x7f\xffabc"));
    print(len(hexed(b"")));
    back = unhexed("00 7f FF\t61");
    print(len(back), back[0], back[1], back[2], back[3]);
    print(unhex_error("0g"));
    print(unhex_error("abc"));
    print(b"abZ\xe9".upper().hex(), b"ABz\xc9".lower().hex());
    print(stripped(b"  a b \n", None), stripped(b"xxaxx", b"x"));
    print(shown(b"  a  b c  ".split()), split_by(b"  a  b c  ", None, 1));
    print(split_by(b"a,b,,c", b",", -1), split_by(b"a,b,,c", b",", 2));
    print(b"aXbXc".replace(b"X", b"--").hex(), b"ab".replace(b"", b"-", 2).hex());
}

glob empty: list[bytes] = [];
with entry {
    print(b", ".join([b"a", b"b"]).hex(), len(b"x".join(empty)));
}
