"""First CPython reference reimplementation: Python/pystrcmp.c via c2jac."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "cpython/pystrcmp.c";

test "cpython/pystrcmp.c transpiles both comparison functions" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "def PyOS_mystrnicmp" in jac_str , jac_str;
    assert "def PyOS_mystricmp" in jac_str , jac_str;
    assert "def py_tolower" in jac_str , jac_str;
}

test "cpython/pystrcmp.c maps const char * params to str" {
    jac_str = _transpile(_FIXTURE);
    assert "s1: str" in jac_str , jac_str;
    assert "s2: str" in jac_str , jac_str;
}

test "cpython/pystrcmp.c: both compare loops are fully Tier-A" {
    # mystrnicmp's `for ( ; --size > 0 && *p1 && *p2; ...)` used to hit Tier-B
    # because the pre-decrement `--size` in the condition had no faithful
    # expression-position lowering. It now lowers to a Jac walrus
    # `(size := size - 1)` — whose value IS the new value, matching C's prefix
    # semantics — so the whole function is Tier-A alongside mystricmp.
    (jac_str, tags) = transpile_c_str(_read(_FIXTURE), "pystrcmp.c");
    assert tier_b_site_count(tags) == 0 , f"expected 0 Tier-B sites, got {tier_b_site_count(
        tags
    )}";
    assert "__c2jac_unsupported" not in jac_str , jac_str;
    # The pre-decrement surfaces as a walrus assignment in the emitted Jac.
    assert "size := (size - 1)" in jac_str , jac_str;
}

test "cpython/pystrcmp.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "pystrcmp.c");
    assert errs == [] , f"recompile errors: {errs}";
}
