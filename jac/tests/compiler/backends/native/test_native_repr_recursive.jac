"""A refused text helper takes back the helpers it started.

str of a base-typed value runs the subclass text that defines it, so the
helper for `Node` starts the helper for `Entry`, which calls back into
`Node`'s. When a field of `Entry` refuses, the helpers started under it go
with it; a kept one called the dropped helper and the emitter refused the
whole module (JacPython's lsprof)."""

import ctypes;
import from tests.support { compile_native, get_func }

test "a refused subclass text helper leaves no call to a dropped helper" {
    # `show` itself runs in Python (repr of a C pointer field has no native
    # text); the module still lowers, so `plain` is native.
    (engine, _) = compile_native("repr_recursive_refusal.jac");
    plain = get_func(engine, "plain", ctypes.c_int64, ctypes.c_int64);
    assert plain(3) == 4;
}
