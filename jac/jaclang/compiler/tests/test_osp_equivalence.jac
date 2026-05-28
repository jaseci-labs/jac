"""Cross-backend Object-Spatial equivalence tests.

One OSP program per fixture, run on every backend that supports it, with the
results compared (intersection semantics: a backend that returns {} or fails to
compile is silently skipped). This is the executable check on the OSP kernel's
core promise — the same `spawn`/ability dispatch behaves identically whether the
program is run by the server runtime (py) or compiled natively (na).

Reuses the cross-backend harness from `test_prim_equivalence`. Comparisons use
only portable logical data (walker state, report values as int lists), never
backend-specific identity (anchor ids / uuids / pointers).

Scope today: native OSP is entry-only (no `visit`/edge-ref yet) and cl OSP
codegen is not wired, so fixtures stay on the entry-dispatch subset and cl is
skipped automatically. Richer traversals (visit order, exit abilities, DFS
ordering) get added as each backend's support lands.
"""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both }

test "osp acc: typed entry ability accumulates walker state across spawns" {
    run_with_both("osp_acc.jac", "acc_py", "acc_cl", "acc_na");
}
