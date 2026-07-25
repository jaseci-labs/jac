"""Cross-backend equivalence for literal-name reflection builtins (#7685).

Pins the Phase 2 parity lowering: `getattr`/`setattr`/`hasattr` with
string-literal names naming declared `has` fields behave identically on the
Python reference and the native backend, including the 3-arg `getattr`
default edge for an undeclared literal name.
"""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both }

test "literal-name reflection builtins py/na parity" {
    run_with_both(
        "reflection_parity.jac",
        "reflect_py",
        "reflect_cl",
        "reflect_na",
        require=["na"]
    );
}
