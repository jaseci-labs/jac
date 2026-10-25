"""finditer hands back an iterator, as CPython's does: a loop and next() both step it."""

import re;

def spans(s: str) -> list[int] {
    out: list[int] = [];
    for m in re.finditer(r"o+", s) {
        out.append(m.start());
    }
    return out;
}

def first_end(s: str) -> int {
    return next(re.finditer(r"\d+", s)).end();
}

def window_count(s: str) -> int {
    n = 0;
    for m in re.compile(r"a").finditer(s, 1, 4) {
        n += 1;
    }
    return n;
}

def none_found(s: str) -> int {
    n = 0;
    for m in re.finditer(r"zz", s) {
        n += 1;
    }
    return n;
}

with entry {
    print(
        spans("foo boo"), first_end("ab12cd"), window_count("aaaaa"), none_found("abc")
    );
}
