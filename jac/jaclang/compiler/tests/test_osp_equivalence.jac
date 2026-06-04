"""Cross-backend Object-Spatial equivalence tests.

One OSP program per fixture, run on every backend that supports it, with the
results compared (intersection semantics: a backend that returns {} or fails to
compile is silently skipped). This is the executable check on the OSP kernel's
core promise -- the same `spawn`/`visit`/ability dispatch behaves identically
whether the program is run by the server runtime (py) or compiled natively (na)
or to JS (cl).

Each test does two things:
  1. Pins the canonical sv (py) semantics with a concrete `run_py_fixture`
     assertion, so the kernel's behavior is a hard regression guard even while
     only one backend runs the fixture.
  2. Enforces cross-backend equivalence via `run_with_both`, with `require=`
     naming the backends that MUST match today. As na/cl OSP lowering lands, a
     fixture's `na {}` / `cl {}` entry variant is added and its backend is moved
     into `require=` -- turning "support landed" into an enforced regression.

Comparisons use only portable logical data (walker state, report values as int
lists), never backend-specific identity (anchor ids / uuids / pointers).

Backend support today (see each fixture's docstring for specifics):
  - na: entry-only spawn, EXACT-type dispatch. No visit / edges / report /
    disengage; exit abilities compile but do not fire; no subtype dispatch.
    So only the entry-only fixtures (`osp_acc`, `osp_multi_walker`,
    `osp_nested_spawn`) carry `require=["na"]`.
  - cl: runs local-archetype walkers in-process through the kernel -- entry
    dispatch, `visit`, edge connect/refs, `disengage`, `report`, exit abilities,
    and subtype / tuple-trigger dispatch -- so every fixture carries
    `require=["cl"]`.
"""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both, run_py_fixture }

# ---------------------------------------------------------------------------
# Entry-only subset -- na participates today (require=["na"]).
# ---------------------------------------------------------------------------
test "osp acc: typed entry ability accumulates walker state across spawns" {
    assert run_py_fixture("osp_acc", "acc_py") == {"total": 42};
    run_with_both("osp_acc.jac", "acc_py", "acc_cl", "acc_na", require=["na", "cl"]);
}

test "osp multi-walker: independent walkers do not share state" {
    assert run_py_fixture("osp_multi_walker", "multi_walker_py") == {"a": 10, "b": 100};
    run_with_both(
        "osp_multi_walker.jac",
        "multi_walker_py",
        "multi_walker_cl",
        "multi_walker_na",
        require=["na", "cl"]
    );
}

test "osp nested spawn: an ability spawns a second walker and folds its result" {
    assert run_py_fixture("osp_nested_spawn", "nested_spawn_py") == {"sum": 8};
    run_with_both(
        "osp_nested_spawn.jac",
        "nested_spawn_py",
        "nested_spawn_cl",
        "nested_spawn_na",
        require=["na", "cl"]
    );
}

# ---------------------------------------------------------------------------
# Traversal subset -- cl runs these in-process through the kernel (visit, edge
# connect/refs, disengage, report, exit abilities), so they are enforced
# cross-backend on cl (require=["cl"]). na still rejects visit/edges/report/
# disengage with E5090, so it is skipped automatically. `subtype_dispatch` also
# runs on cl via the emitted subtype `is_a` table.
# ---------------------------------------------------------------------------
test "osp visit order: chain / diamond / fan-out / cycle DFS traversal" {
    assert run_py_fixture("osp_visit_order", "visit_order_py") == {
        "chain": [1, 2, 3, 4],
        "diamond": [1, 2, 3, 4, 4],
        "fanout": [1, 2, 3, 4],
        "cycle": [1, 2, 3]
    };
    run_with_both(
        "osp_visit_order.jac",
        "visit_order_py",
        "visit_order_cl",
        "visit_order_na",
        require=["cl"]
    );
}

test "osp exit ordering: entry-before-children, exit-after (shared-queue nesting)" {
    assert run_py_fixture("osp_exit_ordering", "exit_ordering_py") == {
        "order": [1, 2, 3, -3, -2, -1]
    };
    run_with_both(
        "osp_exit_ordering.jac",
        "exit_ordering_py",
        "exit_ordering_cl",
        "exit_ordering_na",
        require=["cl"]
    );
}

test "osp subtype dispatch: `with Base entry` fires on Sub; tuple trigger" {
    assert run_py_fixture("osp_subtype_dispatch", "subtype_dispatch_py") == {
        "base": 5,
        "either": 12
    };
    run_with_both(
        "osp_subtype_dispatch.jac",
        "subtype_dispatch_py",
        "subtype_dispatch_cl",
        "subtype_dispatch_na",
        require=["cl"]
    );
}

test "osp disengage: early-exit captures the partial visit set" {
    assert run_py_fixture("osp_disengage", "disengage_py") == {"seen": [1, 2, 3]};
    run_with_both(
        "osp_disengage.jac",
        "disengage_py",
        "disengage_cl",
        "disengage_na",
        require=["cl"]
    );
}

test "osp report: per-walker reports survive the spawn boundary" {
    assert run_py_fixture("osp_report", "report_py") == {"reports": [10, 20, 30]};
    run_with_both(
        "osp_report.jac", "report_py", "report_cl", "report_na", require=["cl"]
    );
}

test "osp edge typed: `[->:Road:->]` follows only the typed edge" {
    assert run_py_fixture("osp_edge_typed", "edge_typed_py") == {"seen": [1, 2, 4]};
    run_with_both(
        "osp_edge_typed.jac",
        "edge_typed_py",
        "edge_typed_cl",
        "edge_typed_na",
        require=["cl"]
    );
}
