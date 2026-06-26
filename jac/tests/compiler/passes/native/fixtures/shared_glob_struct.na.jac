"""Fixture for `jac nacompile --shared` with a GLOBAL CLIB STRUCT.

Regression guard for the `--shared` glob-init bug (commit e7afd1d82 collapsed
the own-module glob-init detection to a single unquoted substring pattern).
LLVM quotes the symbol -- the IR is `define void @"__jac_glob_init"()` -- so the
unquoted `"@__jac_glob_init("` scan missed it and `__jac_shared_init` was
emitted empty. The global `g` then never ran its `my_struct()` initializer, the
struct-pointer slot stayed NULL, and `set_struct_field` / `read_struct_field`
segfaulted on first field access (the CEF dispatch helper died here).

This fixture is the first `--shared` consumer with a *global clib struct*
(scalars/ints don't exercise the glob-init path at all); building + dlopen-ing
it and calling `read_struct_field` is the end-to-end check.
"""

import from "libc.so.6" {
    obj my_struct {
        has a: int = 0,
            b: int = 0,
            c: i32 = 0;
    }
}

# Module-global clib struct: its initializer runs in __jac_glob_init, which
# __jac_shared_init must call when the .so is dlopen'd.
glob g: my_struct = my_struct();

def:pub set_struct_field(v: int) -> int {
    g.a = v;
    return g.a;
}

def:pub read_struct_field() -> int {
    return g.a;
}
