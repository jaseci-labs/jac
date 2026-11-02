"""Builtins whose text can be a shared static string (an ASCII chr(), the
text of a bool) hand their caller a copy it owns under nogc, so a local or a
container that keeps the result frees it without touching the static, and a
temporary list of such text joined in place is dropped once."""

def texts(i: int) -> int {
    c = chr(65 + i % 26);
    wide = chr(0x3b1 + i % 3);
    flag = str(i > 3);
    shown = repr(i % 2 == 0);
    letters = [chr(97 + k) for k in range(3)];
    kept: list[str] = [];
    kept.append(chr(66));
    kept.append(str(i < 2));
    joined = "".join([chr(65 + k) for k in range(3)]);
    return len(c)
        + (1 if wide != c else 0)
        + len(flag)
        + len(shown)
        + len("".join(letters))
        + len(kept)
        + len(joined);
}

with entry {
    print("".join([chr(65 + i) for i in range(3)]));
    total = 0;
    for i in range(40) {
        total += texts(i);
    }
    print(total);
}
