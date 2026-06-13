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
        require=["na", "cl"]
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
        require=["na", "cl"]
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
        require=["na", "cl"]
    );
}

test "osp disengage: early-exit captures the partial visit set" {
    assert run_py_fixture("osp_disengage", "disengage_py") == {"seen": [1, 2, 3]};
    run_with_both(
        "osp_disengage.jac",
        "disengage_py",
        "disengage_cl",
        "disengage_na",
        require=["na", "cl"]
    );
}

test "osp visit-else + disengage-return: else fires at dead ends; post-disengage code never runs" {
    assert run_py_fixture("osp_visit_else", "visit_else_py") == {
        "seen": [1, 2, 3],
        "ends": 1,
        "hseen": [1, 2],
        "tail": 0
    };
    run_with_both(
        "osp_visit_else.jac",
        "visit_else_py",
        "visit_else_cl",
        "visit_else_na",
        require=["na"]
    );
}

test "osp report: per-walker reports survive the spawn boundary" {
    assert run_py_fixture("osp_report", "report_py") == {"reports": [10, 20, 30]};
    run_with_both(
        "osp_report.jac", "report_py", "report_cl", "report_na", require=["na", "cl"]
    );
}

test "osp edge typed: `[->:Road:->]` follows only the typed edge" {
    assert run_py_fixture("osp_edge_typed", "edge_typed_py") == {"seen": [1, 2, 4]};
    run_with_both(
        "osp_edge_typed.jac",
        "edge_typed_py",
        "edge_typed_cl",
        "edge_typed_na",
        require=["na", "cl"]
    );
}

test "osp visit list: walker-field and inline list targets enqueue element-wise" {
    # Issue #6636 (#1): native wrapped a list target as ONE location and the
    # binary aborted after a clean compile. The list must pass through whole.
    assert run_py_fixture("osp_visit_list", "visit_list_py") == {
        "field": 3,
        "inline": 12
    };
    run_with_both(
        "osp_visit_list.jac",
        "visit_list_py",
        "visit_list_cl",
        "visit_list_na",
        require=["na"]
    );
}

test "osp skip guard: `skip` + node-identity `in` dedupes a re-spawned node" {
    # Issue #6636 (#2): native silently dropped `skip`, so the documented
    # user-managed visit-once guard never fired and the count doubled.
    assert run_py_fixture("osp_skip_guard", "skip_guard_py") == {"count": 1};
    run_with_both(
        "osp_skip_guard.jac",
        "skip_guard_py",
        "skip_guard_cl",
        "skip_guard_na",
        require=["na"]
    );
}

test "osp edge nav: every edge-ref form (typed/untyped, edges, node-filter, explicit origin)" {
    # Issue #6642 Blocker 1: edge-ref trailers lower as general expressions
    # (assigned + len()), with the real origin (here / a local / a def param)
    # and node-type filters ([?:Area]) — not only as a bare `visit` target.
    assert run_py_fixture("osp_edge_nav", "edge_nav_py") == {
        "ports": 1,
        "nbrs": 1,
        "ents": 2,
        "areas": 2,
        "world_areas": 2,
        "area_of": 1
    };
    run_with_both(
        "osp_edge_nav.jac", "edge_nav_py", "edge_nav_na", "edge_nav_na", require=["na"]
    );
}

test "osp edge del: `del e` removes the edge from the adjacency (rewire)" {
    # Issue #6642 Blocker 3: `del <edge>` disconnects it; after a rewire the
    # entity has exactly one In edge (the old one was removed, not left behind).
    assert run_py_fixture("osp_edge_del", "edge_del_py") == {
        "before": 1,
        "after_edges": 1,
        "now_in": 1
    };
    run_with_both(
        "osp_edge_del.jac", "edge_del_py", "edge_del_na", "edge_del_na", require=["na"]
    );
}

test "osp cross-module: spawn / connect / edge-ref on imported archetypes" {
    # Issue #6642 Blocker 2: archetypes defined in osp_xmod_lib.na.jac, wired +
    # walked from the consumer osp_xmod_main.na.jac. Imported OSP archetypes
    # materialize into the consumer's deterministic tag space, so spawn / connect
    # and the imported walker body's own edge-refs all lower across the boundary
    # and agree at runtime. Native-only (a .na.jac library is not @sv-importable);
    # the @sv result {"seen": 7, "ports": 2} is pinned in the fixture docstring.
    import os;
    import jaclang;
    import from jaclang.compiler.tests.xbackend_equiv {
        compile_native,
        run_native_function
    }
    _xmod = os.path.join(
        os.path.dirname(os.path.dirname(jaclang.__file__)),
        "tests",
        "compiler",
        "passes",
        "native",
        "fixtures",
        "osp_xmod_main.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "xmod_na") == {"seen": 7, "ports": 2};
}

test "osp cross-module general: consumer with its OWN OSP archetype still agrees" {
    # Issue #6642 follow-up: the deterministic sorted-name tag scheme only held
    # when the consumer defined no local OSP archetypes (a local name sorting
    # before a shared one shifted every tag and silently mis-walked). Globally
    # stable per-archetype tags make the library's tags and the consumer's tags
    # agree no matter what else the consumer defines, so a consumer that ALSO
    # declares `Bot` materializes the imports and runs correctly.
    import os;
    import jaclang;
    import from jaclang.compiler.tests.xbackend_equiv {
        compile_native,
        run_native_function
    }
    _xmod = os.path.join(
        os.path.dirname(os.path.dirname(jaclang.__file__)),
        "tests",
        "compiler",
        "passes",
        "native",
        "fixtures",
        "osp_xmod_local.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "xmod_local_na") == {
        "seen": 7,
        "ports": 2,
        "bot": 3
    };
}

test "osp cross-module two libraries: OSP imported from two modules agrees" {
    # Issue #6642 follow-up: a consumer importing OSP archetypes from TWO
    # independent libraries. Position-based tags collided across libraries;
    # globally stable hash tags make every module agree without coordination.
    import os;
    import jaclang;
    import from jaclang.compiler.tests.xbackend_equiv {
        compile_native,
        run_native_function
    }
    _xmod = os.path.join(
        os.path.dirname(os.path.dirname(jaclang.__file__)),
        "tests",
        "compiler",
        "passes",
        "native",
        "fixtures",
        "osp_xmod_two.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "xmod_two_na") == {"total": 7, "power": 9};
}

test "osp bare edge: `a +>: E :+> b` (bare type) records the edge like `E()`" {
    # Issue #6642 follow-up: native silently DROPPED a bare-edge-type connect
    # (codegen of a bare archetype name yielded no value), so the edge was never
    # recorded and the walk found nothing.
    assert run_py_fixture("osp_bare_edge", "bare_edge_py") == {"hits": 3};
    run_with_both(
        "osp_bare_edge.jac",
        "bare_edge_py",
        "bare_edge_na",
        "bare_edge_na",
        require=["na"]
    );
}
