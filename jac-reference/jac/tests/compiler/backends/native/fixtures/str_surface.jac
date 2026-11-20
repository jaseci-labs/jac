"""The native string surface in one module: literals, concat, repeat,
slices, indexing, comparison, membership, the method set, f-strings,
int round-trip, dict[str] keys, list[str] grow, match on strings, and
string borrows -- in the shapes the enforced zero-RC build licenses.
Fixture for the helper-layer and descriptor migration gates."""

def mix(acc: int, s: &str) -> int {
    h = acc;
    for i in range(len(s)) {
        h = (h * 131 + ord(s[i])) % 1000000007;
    }
    return h;
}

def build_word(seed: int) -> str {
    letters: own str = "abcdefghij";
    w: own str = "";
    s = seed;
    for i in range(6) {
        s = (s * 1103515245 + 12345) % 2147483648;
        w = w + letters[s % 10];
    }
    return w;
}

def run(n: int) -> int {
    words: list[str] = [];
    for i in range(n) {
        words.append(build_word(i + 1));
    }
    h = 1;
    for i in range(len(words)) {
        w = words[i];
        h = mix(h, &w);
        up = w.upper();
        h = mix(h, &up);
        low = up.lower();
        h = mix(h, &low);
        piece = w[1:4];
        h = mix(h, &piece);
        fs = f"{w}:{i:04}";
        h = mix(h, &fs);
        rep = (w * 2).replace("a", "z");
        h = mix(h, &rep);
        if w.startswith("a") {
            h = (h * 3 + 1) % 1000000007;
        }
        if w.endswith("j") {
            h = (h * 5 + 2) % 1000000007;
        }
        if "cd" in w {
            h = (h * 7 + 3) % 1000000007;
        }
        h = (h + w.find("e") + 2) % 1000000007;
        h = (h + w.count("a")) % 1000000007;
        if w < "m" {
            h = (h + 11) % 1000000007;
        }
        if w == up.lower() {
            h = (h + 13) % 1000000007;
        }
        h = (h + len(w) + int(str(i * 3))) % 1000000007;
    }
    joined = "-".join(words[0:8]);
    h = mix(h, &joined);
    parts = joined.split("-");
    h = (h + len(parts)) % 1000000007;
    trimmed = ("  " + words[0] + "  ").strip();
    h = mix(h, &trimmed);
    seen: dict[str, int] = {};
    for i in range(len(words)) {
        k = words[i][0:2];
        if k in seen {
            seen[k] = seen[k] + 1;
        } else {
            seen[k] = 1;
        }
    }
    h = (h + len(seen)) % 1000000007;
    m: own str = "start";
    match m {
        case "start":
            h = (h + 5) % 1000000007;

        case _:
            h = (h + 7) % 1000000007;

    }
    return h;
}

with entry {
    print("strsurface:" + str(run(24)));
}
