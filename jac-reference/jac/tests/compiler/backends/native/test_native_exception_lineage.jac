"""`except Base` catches a user-defined subclass of `Base` natively.

Handler type ids came from a static descendant table that holds only the
builtin hierarchy, so `except AppError` matched `AppError` itself and never
a raised `StoreError(AppError)`: the exception escaped the handler and the
process aborted. Raises of user exception classes now record their ancestors
in a process-wide lineage table that handlers consult, which also covers a
subclass defined in a module the handler never imports.
"""

import ctypes;
import from tests.support { compile_native, get_func }

def call(eng: any, name: str) -> int {
    return get_func(eng, name, ctypes.c_int64)();
}

test "a subclass raised in the same frame is caught by its base" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "same_frame") == 1;
}

test "a two-level subclass raised in a callee is caught by its base" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "two_levels") == 2;
}

test "a subclass of a builtin exception is caught by the builtin" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "builtin_base") == 3;
}

test "a from-imported exception class is caught by name" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "imported_name") == 4;
}

test "an imported subclass is caught by its imported base" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "imported_base") == 4;
}

test "a handler catches a subclass from a module it never imports" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "unseen_subclass") == -1;
}

test "an unrelated handler lets the subclass through to the next clause" {
    (eng, _) = compile_native("exc_lineage_main.jac");
    assert call(eng, "falls_through") == 6;
}
