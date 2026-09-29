"""bytes.hex() and bytes.fromhex(), natively and in Python."""
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

with entry {
    print(hexed(b"\x00\x7f\xffabc"));
    print(len(hexed(b"")));
    back = unhexed("00 7f FF\t61");
    print(len(back), back[0], back[1], back[2], back[3]);
    print(unhex_error("0g"));
    print(unhex_error("abc"));
}
