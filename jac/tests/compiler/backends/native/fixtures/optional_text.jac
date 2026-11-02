"""Optional values render as their payload's text or as `None`."""

obj Tag {
    has name: str = "";

    def __str__ -> str {
        return "Tag(" + self.name + ")";
    }
}

def pick(flag: bool) -> str | None {
    if flag {
        return "val";
    }
    return None;
}

def names(flag: bool) -> list[str] | None {
    if flag {
        return ["a", "b"];
    }
    return None;
}

def num(flag: bool) -> int | None {
    if flag {
        return 42;
    }
    return None;
}

def ratio(flag: bool) -> float | None {
    if flag {
        return 0.5;
    }
    return None;
}

def maybe_flag(flag: bool) -> bool | None {
    if flag {
        return False;
    }
    return None;
}

def tag(flag: bool) -> Tag | None {
    if flag {
        return Tag(name="t");
    }
    return None;
}

def render(flag: bool) -> int {
    x = pick(flag);
    print(x);
    print(f"{x}", f"x={x}!", str(pick(flag)));
    l = names(flag);
    print(l);
    print(f"{l}");
    n = num(flag);
    print(n, f"{n}");
    r = ratio(flag);
    print(r, f"<{r}>");
    t = tag(flag);
    print(t, f"[{t}]");
    m = maybe_flag(flag);
    print(m, f"{m}");
    print(pick(flag), f"{pick(flag)}", f"{names(flag)}");
    print(f"{x!r}", f"{l!r}", f"{n!r}", f"{r!r}", f"{m!r}", f"{pick(flag)!r}");
    return len(f"{x}{l}{n}{r}{t}") + len(f"{x!r}{l!r}{n!r}");
}

with entry {
    total = 0;
    for flag in [True, False] {
        total += render(flag);
    }
    print(total);
}
