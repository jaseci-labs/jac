"""f-string sizing and format specs (issue #7320 Cluster 2, item 2f).

Before the fix every f-string rendered into a fixed 1024-byte buffer
(silent truncation of wire/ANSI payloads) and format specs like :.2f or
:04d were dropped on the floor.
"""

def:pub fstring_long -> int {
    big = "x" * 600;
    msg = f"[{big}][{big}]";
    return len(msg);
}

def:pub fstring_specs -> int {
    pi = 3.14159;
    a = f"{pi:.2f}";
    n = 255;
    b = f"{n:04d}";
    c = f"{n:x}";
    s = "hi";
    d = f"{s:>4}|{s:<4}|";
    ok_a = 1 if a == "3.14" else 0;
    ok_b = 1 if b == "0255" else 0;
    ok_c = 1 if c == "ff" else 0;
    ok_d = 1 if d == "  hi|hi  |" else 0;
    return ok_a * 1000 + ok_b * 100 + ok_c * 10 + ok_d;
}

def:pub fstring_repr -> int {
    q = chr(39);
    dq = chr(34);
    ok1 = 1 if f"{42!r}" == "42" else 0;
    ok2 = 1 if f"{2.5!r}" == "2.5" else 0;
    ok3 = 1 if f"{False!r}" == "False" else 0;
    ok4 = 1 if f"{'a' + q + 'b'!r}" == dq + "a" + q + "b" + dq else 0;
    ok5 = 1 if f"{'x'!r:>6}" == "   'x'" else 0;
    return ok1 * 10000 + ok2 * 1000 + ok3 * 100 + ok4 * 10 + ok5;
}

def:pub fstring_dynspec -> int {
    w = 7;
    p = 2;
    ok_a = 1 if f"{3.14159:{w}.{p}f}" == "   3.14" else 0;
    ok_b = 1 if f"{255:{w}x}" == "     ff" else 0;
    ok_c = 1 if f"{255:0{w}d}" == "0000255" else 0;
    ok_d = 1 if f"{'hi':*^{w}}" == "**hi***" else 0;
    return ok_a * 1000 + ok_b * 100 + ok_c * 10 + ok_d;
}

def:pub fstring_dynspec_invalid -> int {
    bad = "zz";
    try {
        s = f"{1:{bad}}";
        return 100 + len(s);
    } except ValueError {
        return 1;
    }
    return 0;
}

with entry {
    fstring_long();
}
