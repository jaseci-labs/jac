"""Regression fixture for native keyword-argument binding (issue #7026).

Before the fix, keyword arguments in a native call were silently dropped: a
`KWPair` had no expression lowering, so the call collected no value for it and
`_fill_default_args` substituted the parameter's default (or a NULL/zero
fallback). The keyword-supplied value never reached the parameter.

Each function below pins the expected result of binding a keyword to its named
parameter (including reordering and mixing with omitted defaults) across the
three call paths that share the binding logic: free function, method, and an
imported (cross-module) callee.

`greet(name, n)` returns `len(name) * 100 + n`, which makes every binding error
observable as a wrong number (the all-defaults bug returns `len("x")*100 + 1 ==
101`).
"""

import from kwargs_lib { lib_greet }

def greet(name: str = "x", n: int = 1) -> int {
    return len(name) * 100 + n;
}

obj Greeter {
    has base: int;

    def greet(name: str = "x", n: int = 1) -> int {
        return self.base + len(name) * 100 + n;
    }
}

# all-positional baseline -> len("abc")*100 + 5 = 305
def test_positional() -> int {
    return greet("abc", 5);
}

# all keyword, in declared order -> len("abcd")*100 + 7 = 407
def test_keyword() -> int {
    return greet(name="abcd", n=7);
}

# keyword for the leading param, trailing default kept -> len("ab")*100 + 1 = 201
def test_keyword_partial() -> int {
    return greet(name="ab");
}

# keyword args supplied out of declared order -> len("abcde")*100 + 9 = 509
def test_keyword_reordered() -> int {
    return greet(n=9, name="abcde");
}

# positional first arg, keyword second -> len("xyz")*100 + 4 = 304
def test_mixed_pos_kw() -> int {
    return greet("xyz", n=4);
}

# keyword call on a method -> 1000 + len("hi")*100 + 6 = 1206
def test_method_keyword() -> int {
    g = Greeter(base=1000);
    return g.greet(name="hi", n=6);
}

# cross-module keyword call (reordered) -> len("hello")*100 + 8 = 508
def test_xmod_keyword() -> int {
    return lib_greet(n=8, name="hello");
}
