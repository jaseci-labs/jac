"""CPython reference reimplementation: Python/mysnprintf.c via c2jac."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "cpython/mysnprintf.c";

test "cpython/mysnprintf.c transpiles snprintf wrappers" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "def PyOS_snprintf" in jac_str , jac_str;
    assert "def PyOS_vsnprintf" in jac_str , jac_str;
}

test "cpython/mysnprintf.c maps buffer params to str" {
    jac_str = _transpile(_FIXTURE);
    assert "str: str" in jac_str , jac_str;
    assert "format: str" in jac_str , jac_str;
}

test "cpython/mysnprintf.c: variadic snprintf is the only Tier-B site" {
    (jac_str, tags) = transpile_c_str(_read(_FIXTURE), "mysnprintf.c");
    assert tier_b_site_count(tags) == 1 , f"expected 1 Tier-B site, got {tier_b_site_count(
        tags
    )}";
    assert "*args" in jac_str , jac_str;
    assert "__c2jac_unsupported" not in jac_str , jac_str;
}

test "cpython/mysnprintf.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "mysnprintf.c");
    assert errs == [] , f"recompile errors: {errs}";
}
