obj Sig {
    has n: int = 0;
}

def outs(k: int) -> list[str] {
    got: list[str] = [];
    if k > 0 {
        got.append("x");
    }
    return got;
}

def names(k: int) -> dict[str, int] {
    got: dict[str, int] = {};
    if k > 0 {
        got["x"] = 1;
    }
    return got;
}

def guard(sig: Sig | None, k: int) -> str {
    if (sig and outs(k)) {
        return "T";
    }
    return "F";
}

def guard_dict(sig: Sig | None, k: int) -> str {
    if sig and names(k) {
        return "T";
    }
    return "F";
}

def guard_or(sig: Sig | None, k: int) -> str {
    return "T" if (outs(k) or sig) else "F";
}

def guard_str(sig: Sig | None, text: str) -> str {
    if sig and text {
        return "T";
    }
    return "F";
}

def pick(sig: Sig | None, k: int) -> int {
    got = sig and outs(k);
    if isinstance(got, list) {
        return len(got);
    }
    return -1;
}

def fallback(sig: Sig | None, k: int) -> int {
    got = outs(k) or sig;
    if isinstance(got, Sig) {
        return got.n;
    }
    return -2;
}

with entry {
    s = Sig();
    print(
        "pick",
        pick(s, 1),
        pick(s, 0),
        pick(None, 1),
        "fallback",
        fallback(Sig(n=7), 0),
        fallback(s, 1)
    );
    print(
        "list",
        guard(s, 0),
        guard(s, 1),
        guard(None, 1),
        "dict",
        guard_dict(s, 0),
        guard_dict(s, 1),
        "or",
        guard_or(None, 0),
        guard_or(None, 1),
        guard_or(s, 0),
        "str",
        guard_str(s, ""),
        guard_str(s, "a")
    );
}
