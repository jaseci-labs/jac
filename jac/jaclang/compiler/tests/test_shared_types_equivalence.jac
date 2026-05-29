"""Cross-backend equivalence for shared (module-level) type declarations.

Module-level `obj`/`node`/`edge`/`walker` are shared across all codespaces: a
single declaration is compiled by every backend whose code references it. This
pins that a shared `obj` declared once and used (unredeclared) by py, cl, and na
entry functions produces identical results on all three backends.
"""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both }

test "shared obj declared once is compiled by py, cl, and na" {
    run_with_both(
        "shared_obj.jac", "shared_py", "shared_cl", "shared_na", require=["na", "cl"]
    );
}
