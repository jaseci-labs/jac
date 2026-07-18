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

with entry {
    fstring_long();
}
