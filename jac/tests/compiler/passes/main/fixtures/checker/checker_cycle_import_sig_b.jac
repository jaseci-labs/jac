"""Bug #CYCLE-IMPORT-1 fixture, module B: imports A back and uses its symbol
in signatures, closing the import cycle at type-resolution time."""

import from checker_cycle_import_sig_a { AThing }

obj BThing {
    has tag: str = "b";
    has friend: AThing | None = None;
}

def make_b() -> BThing {
    return BThing();
}

def wrap_a(x: AThing) -> AThing {
    return x;
}
