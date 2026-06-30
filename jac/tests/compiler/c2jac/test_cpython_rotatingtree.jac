"""CPython reference reimplementation: Modules/rotatingtree.c via c2jac."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.comments { tier_b_site_count }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

glob _FIXTURE: str = "cpython/rotatingtree.c";

test "cpython/rotatingtree.c transpiles tree API and helper" {
    jac_str = _transpile(_FIXTURE);
    assert jac_str != "" , "Expected non-empty Jac output";
    assert "class rotating_node_s" in jac_str , jac_str;
    assert "def RotatingTree_Add" in jac_str , jac_str;
    assert "def RotatingTree_Get" in jac_str , jac_str;
    assert "def RotatingTree_Enum" in jac_str , jac_str;
    assert "def randombits" in jac_str , jac_str;
}

test "cpython/rotatingtree.c maps struct fields" {
    jac_str = _transpile(_FIXTURE);
    assert "key: object" in jac_str , jac_str;
    assert "left: rotating_node_t" in jac_str , jac_str;
    assert "right: rotating_node_t" in jac_str , jac_str;
}

test "cpython/rotatingtree.c is fully Tier-A" {
    (jac_str, tags) = transpile_c_str(_read(_FIXTURE), "rotatingtree.c");
    assert tier_b_site_count(tags) == 0 , f"expected 0 Tier-B sites, got {tier_b_site_count(
        tags
    )}";
    assert "__c2jac_unsupported" not in jac_str , jac_str;
}

test "cpython/rotatingtree.c emitted Jac recompiles" {
    jac_str = _transpile(_FIXTURE);
    errs = _recompile_errors(jac_str, "rotatingtree.c");
    assert errs == [] , f"recompile errors: {errs}";
}
