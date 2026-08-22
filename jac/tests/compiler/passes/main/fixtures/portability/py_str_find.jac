"""Test: Python-congruent str.find usage must not produce W6002."""

def scan(src: str, needle: str) -> int {
    return src.find(needle);
}

def scan_from(src: str, needle: str, start: int) -> int {
    return src.find(needle, start);
}

def use_str_find {
    s = "hello world";
    i = s.find("world");
    pat = "wor";
    j = s.find(pat);
    k = s.find(pat, 2);
    print(i, j, k);
}
