"""Walk multibyte text every way a program can: loops, views, iterators,
generators, comprehensions and f-string formatting."""

glob WORDS: list[str] = ["héllo", "日本語", "🙂x🙂", "abc", "", "è"];

def each(s: str) -> Iterator[str] {
    for ch in s {
        yield ch;
    }
}

def walk(w: str) -> int {
    parts: list[str] = [];
    for ch in w {
        parts.append(ch);
    }
    print("|".join(parts), len(w), w[::-1], w[1:3], w[::-2]);
    doubled = [ch + ch for ch in w];
    print("".join(doubled));
    gathered: list[str] = [];
    for ch in each(w) {
        gathered.append(ch);
    }
    print("/".join(gathered));
    if len(w) > 0 {
        print(w[0], w[-1], ord(w[-1]));
        v = w[1:];
        print(len(v), v[::-1], "".join([c for c in v]));
    }
    return len(parts);
}

def run -> int {
    big = "日本" * 40000 + "é";
    n = 0;
    for ch in big {
        if ch == "本" {
            n += 1;
        }
    }
    print(n, len(big));
    v = big[3:];
    m = 0;
    for ch in v {
        m += 1;
    }
    print(m, len(v));
    total = 0;
    for w in WORDS {
        total += walk(w);
    }
    print(f"[{'日本語':.2}] [{'é':3}] [{'ab':>4}] [{'日本語':>5.1}]");
    print("è".strip("é"), "éaé".strip("é"), "日x日".lstrip("日"), "x🙂🙂".rstrip("🙂"));
    return total;
}

with entry {
    print(run());
}
