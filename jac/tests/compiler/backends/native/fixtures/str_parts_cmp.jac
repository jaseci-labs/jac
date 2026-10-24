"""String ==/!=/</<=/>/>= lowered inline from (data, len) parts."""

glob G_TAB: str = chr(9);
glob G_AB: str = "ab";
glob G_EMPTY: str = "";

def pick(i: int) -> str {
    if i == 0 { return ""; }
    if i == 1 { return "a"; }
    if i == 2 { return "ab"; }
    if i == 3 { return "abc"; }
    if i == 4 { return "b"; }
    if i == 5 { return "abd"; }
    if i == 6 { return chr(9); }
    return "var";
}

"""Byte-wise lexicographic order of a and b: -1, 0 or 1."""
def ref_order(a: str, b: str) -> int {
    k: int = 0;
    while k < len(a) and k < len(b) {
        ca: int = ord(a[k]);
        cb: int = ord(b[k]);
        if ca < cb { return -1; }
        if ca > cb { return 1; }
        k = k + 1;
    }
    if len(a) < len(b) { return -1; }
    if len(a) > len(b) { return 1; }
    return 0;
}

"""Number of operator results over all operand pairs that disagree with ref_order."""
def:pub matrix_mismatches() -> int {
    bad: int = 0;
    i: int = 0;
    while i < 8 {
        j: int = 0;
        while j < 8 {
            a: str = pick(i);
            b: str = pick(j);
            r: int = ref_order(a, b);
            if (a == b) != (r == 0) { bad = bad + 1; }
            if (a != b) != (r != 0) { bad = bad + 1; }
            if (a < b) != (r < 0) { bad = bad + 1; }
            if (a <= b) != (r <= 0) { bad = bad + 1; }
            if (a > b) != (r > 0) { bad = bad + 1; }
            if (a >= b) != (r >= 0) { bad = bad + 1; }
            j = j + 1;
        }
        i = i + 1;
    }
    return bad;
}

"""Number of wrong results comparing against literals and globs."""
def:pub literal_mismatches() -> int {
    bad: int = 0;
    s: str = pick(2);
    if not (s == "ab") { bad = bad + 1; }
    if s != "ab" { bad = bad + 1; }
    if s == "a" { bad = bad + 1; }
    if s == "abc" { bad = bad + 1; }
    if not ("ab" == s) { bad = bad + 1; }
    if not (pick(0) == "") { bad = bad + 1; }
    if s == "" { bad = bad + 1; }
    if not (s == G_AB) { bad = bad + 1; }
    if not (pick(6) == G_TAB) { bad = bad + 1; }
    if s == G_TAB { bad = bad + 1; }
    if not (pick(0) == G_EMPTY) { bad = bad + 1; }
    if not (pick(7) == "var") { bad = bad + 1; }
    if not (pick(1) >= "a") { bad = bad + 1; }
    if not (pick(1) <= "z") { bad = bad + 1; }
    if not (pick(6) < " ") { bad = bad + 1; }
    if pick(1) < " " { bad = bad + 1; }
    if not (pick(0) < " ") { bad = bad + 1; }
    if pick(0) > " " { bad = bad + 1; }
    return bad;
}
