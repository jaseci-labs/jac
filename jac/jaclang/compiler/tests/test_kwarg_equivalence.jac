"""Cross-backend kwarg call equivalence and JIR cold/warm parity (#6666)."""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both_and_jir_parity }

test "kwarg calls cross-backend and jir parity" {
    run_with_both_and_jir_parity(
        "kwarg_calls.jac", "kwarg_py", "kwarg_cl", "kwarg_na", require=["cl", "na"]
    );
}
