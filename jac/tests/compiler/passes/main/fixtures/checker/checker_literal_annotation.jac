"""Literal[...] type annotations resolve to literal types.

Valid literal values assign and pass; mismatched values error. Distinct
Literal-keyed overloads select by argument value. The trailing block
triggers exactly three errors (one per mismatch).
"""
import from typing { overload }

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
def ok_arg -> str {
    return take_mode('r');
}

def ok_arg2 -> str {
    return take_mode('w');
}

def ok_overload_int(b: Box) -> int {
    return b.pick('a');
}

def ok_overload_str(b: Box) -> str {
    return b.pick('b');
}

def ok_assign -> str {
    x: Literal['a'] = 'a';
    n: Literal[1, 2, 3] = 2;
    flag: Literal[True] = True;
    return f"{x}{n}{flag}";
}

# Literal[None] resolves to NoneType; negative ints resolve too.
def ok_none(x: Literal[None]) -> None {
    return x;
}

def ok_negative(n: Literal[-1, -2]) -> int {
    return n;
}

# --- Invalid: each line is one error ---
def bad_arg -> str {
    return take_mode('x');
}

def bad_overload(b: Box) -> str {
    return b.pick('a');
}

def bad_assign -> str {
    y: Literal['a'] = 'b';
    return y;
}
