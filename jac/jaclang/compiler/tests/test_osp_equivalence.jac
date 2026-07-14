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

test "osp cross-module field read: imported node reserves its OSP header" {
    # Issue #6659 Bug 1: a consumer that only constructs an imported node and
    # reads a field (no spawn/connect/visit -- the module does not "use OSP")
    # still must lay the imported node out with its OSP header (vtable@0,
    # __type_tag@1) so the field offsets match the defining module. Before the
    # fix the consumer dropped the header and `a.tag` read the vtable slot,
    # returning a garbage pointer instead of 7. Native-only (a .na.jac library
    # is not @sv-importable); the @sv result {"tag": 7} is pinned in the fixture.
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
        "xmod_fieldread_main.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "fieldread_na") == {"tag": 7};
}

test "osp cross-module inherited write: write an inherited field of imported node" {
    # Issue #6659 Bug 2: writing (plain or augmented) an INHERITED field of an
    # imported node subtype raised `E5090: field assignment`, while reading the
    # same inherited field worked. The write path must resolve the inherited
    # field's slot through the imported MRO the same way the read path does.
    # Native-only; the @sv result {"yaw": 2.0, "pitch": 0.5} is pinned.
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
        "xmod_inherited_main.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "inherited_na") == {"yaw": 2.0, "pitch": 0.5};
}

test "osp cross-module union return: narrow `Area | None`, read / pass / spawn" {
    # Issue #6659 Bug 3: a cross-module `def f() -> Area | None`, narrowed with
    # `is not None`, then read / passed to an `Area`-typed function / used as a
    # spawn target -- the app-level cascade (E1053 / E1115 / E1099 / runtime
    # crash), all rooted in the imported node layout being unsound across the
    # boundary (same root as Bug 1). Native-only; the @sv result {"present": 5,
    # "taken": 5, "hits": 5, "absent": -1} is pinned.
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
        "xmod_unionret_main.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "unionret_na") == {
        "present": 5,
        "taken": 5,
        "hits": 5,
        "absent": -1
    };
}

test "xmod narrow: `is not None` narrowing applies on the imported-module path" {
    # Issue #6667: `T | None` narrowed with `is not None` (block and ternary)
    # narrowed correctly when the code was the entry module but stayed
    # `T | None` (E1099 / E1115 / E1053) when the same code lived in an
    # `import`ed module. The imported-dependency compile path ran type
    # inference without first building the CFG that flow-narrowing walks. Here
    # the narrowing lives in xmod_narrow_lib.use_it (imported by the entry
    # xmod_narrow_main), so it exercises exactly that path. Native-only; the
    # @sv result {"present": "hit", "size": 5, "absent": "void"} is pinned.
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
        "xmod_narrow_main.na.jac"
    );
    (_eng, _) = compile_native(_xmod);
    assert run_native_function(_eng, "narrow_na") == {
        "present": "hit",
        "size": 5,
        "absent": "void"
    };
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

test "osp field access: reading a field off an edge-ref / filtered node-ref element" {
    # Issue #6646: an edge-ref / node-ref yields opaque handles; reading `.field`
    # off one crashed codegen (node loop var) or E5090'd (edge subscript) because
    # the handle was not recovered to the archetype struct layout. Edge fields
    # and FILTERED node fields (whose element type the checker can resolve) now
    # read correctly.
    assert run_py_fixture("osp_field_access", "field_access_py") == {
        "first_cx": 42.0,
        "sum_cx": 50.0,
        "nbr_tag": 99,
        "direct": 42.0
    };
    run_with_both(
        "osp_field_access.jac",
        "field_access_py",
        "field_access_na",
        "field_access_na",
        require=["na"]
    );
}

test "osp typed edge endpoints: field read off an unfiltered neighbour traversal" {
    # Issue #6657: with `edge Portal: Spot --> Spot`, an UNFILTERED neighbour
    # traversal `[here ->:Portal:->]` narrows to list[Spot], so native recovers
    # the struct layout from the adjacency handle and reads the field correctly
    # -- no `[?:Spot]` filter. (The untyped form of this read still E5090s; see
    # test_native_feature_guardrail.jac.) na must match the py reference.
    assert run_py_fixture("osp_typed_endpoint_field", "typed_endpoint_py") == {
        "count": 2,
        "nbr_tag": 99,
        "sum_tag": 106
    };
    run_with_both(
        "osp_typed_endpoint_field.jac",
        "typed_endpoint_py",
        "typed_endpoint_na",
        "typed_endpoint_na",
        require=["na"]
    );
}
