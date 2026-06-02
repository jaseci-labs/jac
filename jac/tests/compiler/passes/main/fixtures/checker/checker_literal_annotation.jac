"""Literal[...] type annotations resolve to literal types.

Valid literal values assign and pass; mismatched values error. Distinct
Literal-keyed overloads select by argument value. The trailing block
triggers exactly three errors (one per mismatch).
"""

def take_mode(mode: Literal['r', 'w']) -> str {
    return mode;
}

obj Box {
    @overload
    def pick(k: Literal['a']) -> int;
    @overload
    def pick(k: Literal['b']) -> str;
    def pick(k: str) -> int | str {
        return 0;
    }
}

# --- Valid ---
def ok_arg() -> str {
    return take_mode('r');
}

def ok_arg2() -> str {
    return take_mode('w');
}

def ok_overload_int(b: Box) -> int {
    return b.pick('a');
}

def ok_overload_str(b: Box) -> str {
    return b.pick('b');
}

def ok_assign() -> None {
    x: Literal['a'] = 'a';
    n: Literal[1, 2, 3] = 2;
    flag: Literal[True] = True;
    print(x, n, flag);
}

# --- Invalid: each line is one error ---
def bad_arg() -> str {
    return take_mode('x');
}

def bad_overload(b: Box) -> str {
    return b.pick('a');
}

def bad_assign() -> None {
    y: Literal['a'] = 'b';
    print(y);
}

with entry {
    print("literal annotation fixture");
}
