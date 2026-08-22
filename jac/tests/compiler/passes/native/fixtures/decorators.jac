"""Static decorators on module-level native functions.

The decorated symbol's body compiles under a private raw name; a private
function-pointer slot is initialized at module glob-init by applying the
decorator chain (bottom-up) to the raw function, and every call to the
decorated name goes through the slot. Registration decorators observe the
glob-init-time side effect; a decorator that returns a different function
actually redirects calls (the slot is real, not a direct raw call).
"""

glob marks: int = 0;

def mark(fn: any) -> any {
    marks = marks + 1;
    return fn;
}

@mark
def val(x: int) -> int {
    return x + 1;
}

def use_val -> int {
    return val(4) * 100 + marks;
}

def alt(x: int) -> int {
    return x * 2;
}

def to_alt(fn: any) -> any {
    return alt;
}

@to_alt
def val2(x: int) -> int {
    return x;
}

def use_val2 -> int {
    return val2(21);
}

@mark
@mark
def stacked(x: int) -> int {
    return x - 1;
}

def use_stacked -> int {
    return stacked(10) * 10 + marks;
}
