"""String and dict fast paths, at their edges.

Comparisons against a one-character literal on either side, with empty,
equal, longer and non-ASCII strings; `str(int)`, an int's repr and f-strings
at zero, the extremes of `int` and with `%` in the text; and
`d[k] = d.get(k, c) op e` for every operator it takes, with keys that are
missing or present, float values, int keys and a literal key; and floats'
shortest repr: short decimals (the direct path), values that need 16 or 17
digits, both ends of fixed notation, subnormals and the extremes.
"""

def rel(a: str, b: str) -> str {
    return f"{int(a < b)}{int(a <= b)}{int(a == b)}{int(a != b)}{int(a >= b)}{int(
        a > b
    )}";
}

def compares -> list[str] {
    out: list[str] = [];
    for s in ["", "a", "b", "ab", "A", "z", "zz", "é", "\t", "a\x00"] {
        out.append(
            f"{rel(s, 'a')}|{int('a' < s)}{int('a' <= s)}{int('a' == s)}{int('a' > s)}{int(
                'a' >= s
            )}"
        );
    }
    return out;
}

def numbers -> list[str] {
    out: list[str] = [];
    big = 9223372036854775807;
    small = -big - 1;
    for v in [0, 7, -7, 10, -10, 1234567890123, big, small] {
        out.append(str(v));
        out.append(f"<{v}>%{v}%%|{-v if v != small else 0}");
    }
    out.append(f"{True}-{False}-{1.5}-{-0.25}-{'x'}%");
    out.append(repr(12345) + repr(-6));
    return out;
}

def counters -> list[str] {
    words = ["a", "bb", "a", "ccc", "bb", "a", "dd"];
    c: dict[str, int] = {};
    for w in words {
        c[w] = c.get(w, 0) + 1;
    }
    m: dict[str, int] = {};
    for w in words {
        m[w] = m.get(w, 1) * 3;
        m[w] = m.get(w, 0) - 1;
    }
    bits: dict[int, int] = {};
    for i in range(20) {
        k = i % 6;
        bits[k] = bits.get(k, 0) | (1 << i);
        bits[k] = bits.get(k, 255) & 1048575;
        bits[k] = bits.get(k, 0) ^ i;
    }
    f: dict[str, float] = {};
    step = 0.5;
    for w in words {
        f[w] = f.get(w, 1.0) + step;
    }
    lit: dict[str, int] = {};
    for i in range(5) {
        lit["fixed"] = lit.get("fixed", 10) + i;
    }
    return [str(c), str(m), str(bits), str(f), str(lit)];
}

def floats -> list[str] {
    out: list[str] = [];
    for v in [
        0.0,
        -0.0,
        0.1,
        0.1 + 0.2,
        1.0 / 3.0,
        2.25,
        -7.0,
        1e-4,
        1e-5,
        0.000123456,
        999999.999999,
        123456789012345.6,
        1e15,
        1e16,
        5e-324,
        2.2250738585072014e-308,
        1e-310,
        1.7976931348623157e308,
        2.675,
        100000000000000.25,
        9007199254740993.0,
        6.02e23
    ] {
        out.append(f"{v}|{str(-v)}");
    }
    total = 0;
    for i in range(600) {
        total += len(str((i * 7919 % 10007) / 64.0 - 50.0))
            + len(str(i * 0.001))
            + len(str(i / 7.0));
    }
    out.append(str(total));
    return out;
}

with entry {
    for line in compares() + numbers() + counters() + floats() {
        print(line);
    }
}
