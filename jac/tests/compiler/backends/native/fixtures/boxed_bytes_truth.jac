"""`and` and `or` between a bool and bytes box the bytes; their truth and length
come from the bytes' own length whatever its value."""

def with_and(flag: bool, data: bytes) -> str {
    return "T" if flag and data else "f";
}

def with_or(flag: bool, data: bytes) -> str {
    return "T" if flag or data else "f";
}

def in_if(flag: bool, data: bytes) -> str {
    if flag and data {
        return "T";
    }
    return "f";
}

def in_while(flag: bool, data: bytes) -> str {
    while flag and data {
        return "T";
    }
    return "f";
}

def boxed_length(data: any) -> int {
    return len(data);
}

with entry {
    for size in [0, 1, 255, 256, 257, 512, 3072, 65536] {
        data = bytes(size);
        print(
            size,
            with_and(True, data),
            with_or(False, data),
            in_if(True, data),
            in_while(True, data),
            boxed_length(data)
        );
    }
    print(
        with_and(True, b""),
        with_and(True, b"abc"),
        with_or(False, b""),
        with_or(False, b"abc"),
        boxed_length(b"abc")
    );
    for size in [0, 256] {
        text = "x" * size;
        print(size, "T" if True and text else "f", boxed_length(text));
    }
}
