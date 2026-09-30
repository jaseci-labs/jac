"""A conditional expression with one owned arm (a fresh slice) and one
borrowed arm (the parameter itself): the result is owned either way, so the
borrowed arm is copied rather than freed through the result."""

def name_of(raw: &bytes) -> str {
    end = raw.find(b"\x00");
    return (raw[:end] if end >= 0 else raw).decode("utf-8");
}

def shout(text: &str, mark: bool) -> str {
    return (f"{text}!" if mark else text).upper();
}

def probe(i: int) -> int {
    total = len(name_of(b"sbar\x00\x00junk")) + len(name_of(b"nonul"));
    total += len(shout("abcdef", i % 2 == 0)) + len(shout("xy", False));
    return total;
}

with entry {
    total = 0;
    for i in range(20) {
        total += probe(i);
    }
    print(total);
}
