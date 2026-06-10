"""Regression fixture: a module-level function declared with NEITHER a parameter
list NOR a return type (`def foo { ... }`) is semantically `def foo() -> None`
and must compile and run identically.

Bug: the native backend dropped such functions (and their call sites) entirely,
because the parser collapsed the empty FuncSignature to None for the no-parens /
no-return form. `tick` here would vanish, so `run_ticks(n)` returned 0.
"""

glob hits: int = 0;

# No parameter list and no return type -> must behave like `def tick() -> None`.
def tick {
    global hits;
    hits = hits + 1;
}

# Same shape, but written with an explicit empty parameter list. Already worked;
# kept here so the two forms can be asserted equivalent.
def tick_parens() {
    global hits;
    hits = hits + 1;
}

def run_ticks(n: int) -> int {
    global hits;
    hits = 0;
    i: int = 0;
    while i < n {
        tick();
        i = i + 1;
    }
    return hits;
}

def run_ticks_parens(n: int) -> int {
    global hits;
    hits = 0;
    i: int = 0;
    while i < n {
        tick_parens();
        i = i + 1;
    }
    return hits;
}
