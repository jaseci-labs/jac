"""Codepoint access over long non-ASCII strings, where the cursor cache engages.

Every function returns a checksum that `test_native_str_utf8_cursor.jac`
recomputes on CPython. The `scan_*` loops are the shapes that went quadratic
when each index, slice or search converted from byte 0.
"""

glob MOD: int = 1000000007;

def mix(acc: int, v: int) -> int {
    return (acc * 31 + v + 7) % MOD;
}

def next_seed(x: int) -> int {
    return (x * 1103515245 + 12345) % 2147483648;
}

def index_mix(s: str, seed: int, steps: int) -> int {
    n = len(s);
    x = seed;
    acc = n;
    for _ in range(steps) {
        x = next_seed(x);
        acc = mix(acc, ord(s[x % (2 * n) - n]));
    }
    return acc;
}

def walk_both(s: str) -> int {
    acc = 0;
    i = 0;
    while i < len(s) {
        acc = mix(acc, ord(s[i]));
        i += 1;
    }
    i = len(s) - 1;
    while i >= 0 {
        acc = mix(acc, ord(s[i]) + i);
        i -= 2;
    }
    return acc;
}

def slice_mix(s: str, seed: int, steps: int) -> int {
    n = len(s);
    x = seed;
    acc = 0;
    for _ in range(steps) {
        x = next_seed(x);
        a = x % (2 * n + 6) - n - 3;
        x = next_seed(x);
        c = x % (2 * n + 6) - n - 3;
        t = s[a:c];
        acc = mix(acc, len(t));
        if len(t) > 0 {
            acc = mix(acc, ord(t[0]) + ord(t[-1]) + ord(t[len(t) // 2]));
        }
    }
    return acc;
}

def view_mix(s: str, seed: int, steps: int) -> int {
    t = s[3:len(s) - 2];
    u = t[5:];
    x = seed;
    acc = len(t) + len(u);
    for _ in range(steps) {
        x = next_seed(x);
        acc = mix(acc, ord(t[x % len(t)]) + ord(u[x % len(u)]) + ord(s[x % len(s)]));
        acc = mix(acc, len(u[x % len(u):]));
    }
    return acc;
}

def search_mix(s: str, needle: str, seed: int, steps: int) -> int {
    n = len(s);
    x = seed;
    acc = 0;
    for _ in range(steps) {
        x = next_seed(x);
        a = x % (2 * n + 6) - n - 3;
        x = next_seed(x);
        c = x % (2 * n + 6) - n - 3;
        acc = mix(acc, s.find(needle, a, c) + 2);
        acc = mix(acc, s.rfind(needle, a, c) + 2);
        acc = mix(acc, s.count(needle, a, c));
        acc = mix(acc, 1 if s.startswith(needle, a, c) else 0);
        acc = mix(acc, 1 if s.endswith(needle, a, c) else 0);
    }
    return acc;
}

def find_walk(s: str, needle: str) -> int {
    acc = 0;
    i = s.find(needle);
    while i >= 0 {
        acc = mix(acc, i);
        i = s.find(needle, i + 1);
    }
    i = s.rfind(needle);
    while i >= 0 {
        acc = mix(acc, i);
        i = s.rfind(needle, 0, i);
    }
    return acc;
}

"""One round's text: the same byte length every round, with its multibyte
characters at a different place, so a cursor kept from a freed round's string
would land on the wrong character."""
def round_text(r: int) -> str {
    lead = r % 37;
    return "a" * lead
        + "é" * 30
        + "b" * (37 - lead)
        + "語" * 10
        + "c" * (r % 5)
        + "d" * (5 - r % 5);
}

def reuse_mix(rounds: int) -> int {
    acc = 0;
    for r in range(rounds) {
        s = round_text(r);
        acc = mix(acc, ord(s[40]) + ord(s[-3]) + s.find("b") + len(s));
        acc = mix(acc, ord(s[len(s) // 2]) + len(s[10:70]) + s.rfind("é"));
        acc = mix(acc, ord(s[41]) + s.find("語", 50));
    }
    return acc;
}

"""Index `s` in a loop while building and dropping long non-ASCII temporaries,
each of which is cursored once and freed."""
def churn_walk(s: str) -> int {
    acc = 0;
    i = 0;
    while i < len(s) {
        t = s[i:i + 80] + "é";
        acc = mix(acc, ord(s[i]) + len(t) + ord(t[len(t) // 2]));
        i += 1;
    }
    return acc;
}

def scan_index(s: str) -> int {
    n = 0;
    i = 0;
    while i < len(s) {
        if s[i] == "a" {
            n += 1;
        }
        i += 1;
    }
    return n;
}

def scan_slice(s: str) -> int {
    n = 0;
    i = 0;
    while i < len(s) {
        if s[i:i + 1] == "a" {
            n += 1;
        }
        i += 1;
    }
    return n;
}

def scan_find(s: str) -> int {
    n = 0;
    i = s.find("a");
    while i >= 0 {
        n += 1;
        i = s.find("a", i + 1);
    }
    return n;
}

def scan_rfind(s: str) -> int {
    n = 0;
    i = s.rfind("a");
    while i >= 0 {
        n += 1;
        i = s.rfind("a", 0, i);
    }
    return n;
}
