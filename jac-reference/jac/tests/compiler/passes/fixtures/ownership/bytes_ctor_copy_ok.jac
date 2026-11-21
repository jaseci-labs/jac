"""`bytes(x)` and `bytearray(x)` copy their argument; they never consume it."""

def freeze(src: &bytes) -> bytes {
    buf = bytearray(src);
    frozen = bytes(buf);
    grown = bytearray(buf);
    grown.append(46);
    buf.append(33);
    return frozen + bytes(grown) + bytes(buf);
}

with entry {
    print(freeze(b"abc"));
}
