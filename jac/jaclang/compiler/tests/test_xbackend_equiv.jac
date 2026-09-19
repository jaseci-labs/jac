"""The JavaScript equivalence harness accepts bundles larger than argv limits."""

import from jaclang.compiler.tests.xbackend_equiv { run_js_function, run_js_expr }

test "JavaScript equivalence helpers accept large bundles" {
    script = "/*"
        + "x" * (256 * 1024)
        + "*/\n"
        + "function result() { return {value: 42}; }";
    assert run_js_function(script, "result") == {"value": 42};
    assert run_js_expr(script, "result().value") == 42;
}
