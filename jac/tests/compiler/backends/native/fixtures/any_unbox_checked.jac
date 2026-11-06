"""Reading an any value as a scalar checks what it holds. Native code has
one slot type, so a value of another type raises TypeError where it is read;
every mismatch here is one Python also rejects at its first use."""
def pick(i: int) -> any {
    items: list[any] = [7, "seven", 2.5, True, None];
    return items[i];
}

def as_int(i: int) -> str {
    try {
        n: int = pick(i);
        return f"int {n + 1}";
    } except TypeError {
        return "TypeError";
    }
}

def as_float(i: int) -> str {
    try {
        f: float = pick(i);
        return f"float {f * 2.0}";
    } except TypeError {
        return "TypeError";
    }
}

def as_str(i: int) -> str {
    try {
        s: str = pick(i);
        return f"str {len(s)}";
    } except TypeError {
        return "TypeError";
    }
}

def as_bool(i: int) -> str {
    try {
        flag: bool = pick(i);
        return f"bool {flag}";
    } except TypeError {
        return "TypeError";
    }
}

with entry {
    print(as_int(0), as_int(3));
    print(as_float(2), as_float(0));
    print(as_str(1));
    print(as_bool(3));
    print(as_int(1), as_int(4));
    print(as_float(1), as_str(0));
}
