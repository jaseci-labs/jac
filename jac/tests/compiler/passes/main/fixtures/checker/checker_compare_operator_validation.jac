"""Test fixture for comparison operator type validation.

Each line marked with '# <-- Error' should produce a type error.
Lines marked '# <-- OK' should pass without errors.
"""

def ordered_comparisons() {
    # Invalid ordered comparisons between incompatible types
    a = "hello" > 5;         # <-- Error: str vs int
    b = "hello" < [1, 2, 3]; # <-- Error: str vs list
    c = [1, 2] < {3: 4};    # <-- Error: list vs dict

    # Valid ordered comparisons
    d = 1 < 2;               # <-- OK: int vs int
    e = "abc" < "def";       # <-- OK: str vs str
    f = 1.0 <= 2.0;          # <-- OK: float vs float
    g = 1 >= 0;              # <-- OK: int vs int
    h = "z" != "a";          # <-- OK: str vs str
    print(a, b, c, d, e, f, g, h);
}

def membership_tests() {
    # Invalid: right operand has no __contains__
    i = 5 in 10;             # <-- Error: int has no __contains__
    j = "x" in 42;           # <-- Error: int has no __contains__

    # Valid membership tests
    k = "x" in [1, 2, 3];   # <-- OK: list has __contains__
    l = "a" in {"a": 1};    # <-- OK: dict has __contains__
    m = "ab" in "abc";       # <-- OK: str has __contains__
    n = 1 in (1, 2, 3);     # <-- OK: tuple has __contains__
    print(i, j, k, l, m, n);
}

def identity_tests() {
    # is / is not are always valid (identity checks)
    o = "hello" is 5;        # <-- OK (identity)
    p = [1] is not "abc";    # <-- OK (identity)
    q = None is None;        # <-- OK (identity)
    print(o, p, q);
}

def chained_comparisons() {
    # Chained with incompatible types
    r = "a" < 1 < "b";      # <-- Error x2: str<int and int<str
    # Valid chain
    s = 1 < 2 < 3;          # <-- OK: int < int < int
    print(r, s);
}

def equality_comparisons() {
    # == and != between same types are always valid
    t = 1 == 2;              # <-- OK: int.__eq__(int)
    u = "abc" != "def";      # <-- OK: str.__ne__(str)
    v = [1] == [2];          # <-- OK: list.__eq__(list)
    print(t, u, v);
}
