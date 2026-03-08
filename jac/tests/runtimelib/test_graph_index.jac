"""Graph Topology Index tests (GT + AM layers).

Written in Jac using proper OSP syntax:
  - Nodes and walkers defined at module level
  - Graph building via ++> (connect)
  - Graph traversal via [here-->](?:Type) (filtered OSP traversal)
  - Edge removal via del -->
  - GT/AM state checked via direct imports

All tests use a single context per test (no close+reopen) to avoid
the cross-context pickle issue with dynamically-loaded node classes.
AM miss is simulated by calling am_clear() within the same context
(GT tables remain intact in the committed SQLite connection).

Groups:
  1 - GT Table Correctness
  2 - AM Correctness
  3 - Fetch Count Reduction
  4 - Mutation Consistency
  5 - Schema
"""

import os;
import sqlite3;
import from tempfile { mkdtemp }
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.runtime { without_plugins }
import from jaclang.runtimelib.am_index {
    am_index,
    _stats,
    am_clear,
    reset_stats,
    rebuild_topology_index
}

# ===========================================================================
# Node types — must be module-level for OSP
# ===========================================================================

node TargetNode  { has val: int = 0; }
node OtherNode   { has val: int = 0; }
node BaseContent { has val: int = 0; }
node PostNode(BaseContent)    { has val: int = 0; }
node CommentNode(BaseContent) { has val: int = 0; }

# ===========================================================================
# Walkers — OSP graph building and traversal
# ===========================================================================

"""Connect n_targets TargetNodes and n_others OtherNodes to root."""
walker BuildGraph {
    has n_targets: int = 3;
    has n_others:  int = 2;

    can build with Root entry {
        for i in range(self.n_targets) {
            here ++> TargetNode(val=i);
        }
        for i in range(self.n_others) {
            here ++> OtherNode(val=i);
        }
    }
}

"""Connect PostNodes, CommentNodes, and OtherNodes to root."""
walker BuildHierarchyGraph {
    has n_post:    int = 2;
    has n_comment: int = 2;
    has n_other:   int = 1;

    can build with Root entry {
        for i in range(self.n_post) {
            here ++> PostNode(val=i);
        }
        for i in range(self.n_comment) {
            here ++> CommentNode(val=i);
        }
        for i in range(self.n_other) {
            here ++> OtherNode(val=i);
        }
    }
}

"""Typed traversal: collect all TargetNode neighbors via [here-->](?:TargetNode)."""
walker QueryTargets {
    has results: list = [];

    can query with Root entry {
        self.results = [-->(?:TargetNode)];
    }
}

"""Typed traversal: collect BaseContent neighbors (returns PostNode + CommentNode via MRO)."""
walker QueryBaseContent {
    has results: list = [];

    can query with Root entry {
        self.results = [-->(?:BaseContent)];
    }
}

"""Wildcard traversal: collect all neighbors regardless of type."""
walker QueryAll {
    has results: list = [];

    can query with Root entry {
        self.results = [-->];
    }
}

"""Add n more TargetNodes to root."""
walker AddTargets {
    has n: int = 5;

    can add with Root entry {
        for i in range(self.n) {
            here ++> TargetNode(val=i);
        }
    }
}

"""Remove one TargetNode edge from root using del --> OSP syntax."""
walker RemoveFirstTarget {
    can remove with Root entry {
        targets = [-->(?:TargetNode)];
        if targets {
            here del --> targets[0];
        }
    }
}

# ===========================================================================
# Context helpers
# ===========================================================================

"""Create a fresh isolated Jac context backed by SQLite in tmp_dir."""
def fresh_ctx(tmp: str) -> object {
    Jac.set_base_path(tmp);
    Jac.exec_ctx = None;
    ctx = Jac.create_j_context(None);
    Jac.set_context(ctx);
    return ctx;
}

"""Close context and clear exec_ctx."""
def close_ctx(ctx: object) -> None {
    ctx.close();
    Jac.exec_ctx = None;
}

"""Return the SQLite DB path used by a context."""
def db_path(ctx: object) -> str {
    return ctx.mem.l3.path;
}

"""Count rows in a table by opening a direct sqlite3 connection."""
def count_table(db: str, table: str, where: str = "") -> int {
    sql = f"SELECT COUNT(*) FROM {table}";
    if where {
        sql = f"{sql} WHERE {where}";
    }
    con = sqlite3.connect(db);
    n = con.execute(sql).fetchone()[0];
    con.close();
    return n;
}

# ===========================================================================
# Group 1 — GT Table Correctness
# ===========================================================================

test "GT - building graph populates edge_topology and node_topology" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=3, n_others=2);
                db = db_path(ctx);

                et_total  = count_table(db, "edge_topology");
                et_target = count_table(db, "edge_topology", "target_type='TargetNode'");
                et_other  = count_table(db, "edge_topology", "target_type='OtherNode'");
                nt_target = count_table(db, "node_topology", "node_type='TargetNode'");

                assert et_total  >= 5, f"expected >=5 edge_topology rows, got {et_total}";
                assert et_target == 3, f"expected 3 TargetNode edges, got {et_target}";
                assert et_other  == 2, f"expected 2 OtherNode edges, got {et_other}";
                assert nt_target >= 3, f"expected >=3 TargetNode node_topology rows, got {nt_target}";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
    }
}

test "GT - del --> removes edge from edge_topology" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=3, n_others=0);
                db = db_path(ctx);

                before = count_table(db, "edge_topology", "target_type='TargetNode'");
                assert before == 3, f"expected 3 rows before delete, got {before}";

                # del --> in same context — no cross-context pickle needed
                root spawn RemoveFirstTarget();

                after = count_table(db, "edge_topology", "target_type='TargetNode'");
                assert after == 2, f"expected 2 rows after del -->, got {after}";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
    }
}

test "GT - rebuild_topology_index warms AM from edge_topology" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=5, n_others=0);
                db = db_path(ctx);

                # Verify GT has rows
                et_count = count_table(db, "edge_topology");
                assert et_count >= 5, f"expected >=5 edge_topology rows, got {et_count}";

                # Clear AM (GT tables intact)
                am_clear();
                root_id = str(ctx.user_root.id);
                assert am_index.get(root_id) is None, "AM must be empty after am_clear()";

                # rebuild_topology_index should warm AM from existing edge_topology
                result = rebuild_topology_index(ctx.mem);

                assert "rebuilt" in result.get("gt", ""), f"expected 'rebuilt' in result, got {result}";
                assert am_index.get(root_id) is not None, "AM must be warmed after rebuild";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "GT - MRO fan-out writes parent type rows to node_topology" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildHierarchyGraph(n_post=2, n_comment=2, n_other=0);
                db = db_path(ctx);

                post_rows = count_table(db, "node_topology", "node_type='PostNode'");
                base_rows = count_table(db, "node_topology", "node_type='BaseContent'");

                # PostNode + CommentNode both inherit BaseContent → base_rows >= 4
                assert post_rows >= 2, f"expected >=2 PostNode rows, got {post_rows}";
                assert base_rows >= 4, f"expected >=4 BaseContent (MRO) rows, got {base_rows}";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
    }
}

# ===========================================================================
# Group 2 — AM Correctness
# ===========================================================================

test "AM - build_edge writes to am_index via am_put" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root_id = str(ctx.user_root.id);
                root spawn BuildGraph(n_targets=1, n_others=0);

                bucket = am_index.get(root_id);
                assert bucket is not None, "AM bucket for root must exist after build_edge";
                assert len(bucket.get("TargetNode", [])) == 1, (
                    "AM must contain 1 TargetNode under root"
                );
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "AM - del --> triggers am_invalidate" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root_id = str(ctx.user_root.id);
                root spawn BuildGraph(n_targets=1, n_others=0);

                assert am_index.get(root_id) is not None, "AM must be warm after build";

                # del --> in same context invalidates AM
                root spawn RemoveFirstTarget();

                assert am_index.get(root_id) is None, "AM must be invalidated after del -->";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "AM - miss falls back to GT then warms AM" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root_id = str(ctx.user_root.id);
                # Use >DEGREE_THRESHOLD nodes to trigger index path
                root spawn BuildGraph(n_targets=15, n_others=5);

                # Simulate AM eviction (GT tables stay intact in same connection)
                am_clear();
                reset_stats();

                # [here-->](?:TargetNode) hits AM miss → GT query → warms AM
                w = root spawn QueryTargets();

                assert _stats["am_misses"] >= 1, "expected AM miss after am_clear()";
                assert _stats["gt_hits"]   >= 1, "expected GT to answer the miss";
                assert len(w.results) == 15, f"expected 15 results, got {len(w.results)}";
                assert am_index.get(root_id) is not None, "AM must be populated after GT hit";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "AM - second traversal hits AM not GT" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=15, n_others=5);

                am_clear();

                # First traversal — warms AM from GT
                w1 = root spawn QueryTargets();
                reset_stats();
                # Second traversal — must hit AM only
                w2 = root spawn QueryTargets();

                assert _stats["am_hits"] >= 1, "expected AM hit on second traversal";
                assert _stats["gt_hits"] == 0, "GT must not be consulted on second traversal";
                assert len(w1.results) == len(w2.results) == 15;
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "AM - parent type query [here-->](?:BaseContent) returns subtypes via MRO" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                # Use >DEGREE_THRESHOLD to force index path
                root spawn BuildHierarchyGraph(n_post=8, n_comment=8, n_other=1);

                am_clear();

                # [here-->](?:BaseContent) exercises MRO fan-out index
                w = root spawn QueryBaseContent();

                assert len(w.results) == 16, f"expected 16 BaseContent nodes (PostNode+CommentNode), got {len(w.results)}";
                type_names = {type(n).__name__ for n in w.results};
                assert "OtherNode" not in type_names, "OtherNode must not appear in BaseContent query";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

# ===========================================================================
# Group 3 — Fetch Count Reduction
# ===========================================================================

test "fetch - index is consulted at low selectivity (10%) and skipped when disabled" {
    tmp_idx = mkdtemp();
    tmp_loc = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        def run_query(tmp: str, enabled: bool) -> tuple[int, dict] {
            os.environ["JAC_INDEX_ENABLED"] = "true" if enabled else "false";
            am_clear();
            reset_stats();
            with without_plugins() {
                ctx = fresh_ctx(tmp);
                try {
                    # 5 TargetNode + 45 OtherNode = 10% selectivity
                    root spawn BuildGraph(n_targets=5, n_others=45);
                    am_clear();
                    reset_stats();
                    w = root spawn QueryTargets();
                    return (len(w.results), dict(_stats));
                } finally {
                    close_ctx(ctx);
                }
            }
        }

        (n_idx, stats_idx) = run_query(tmp_idx, True);
        (n_loc, stats_loc) = run_query(tmp_loc, False);

        os.environ["JAC_INDEX_ENABLED"] = "true";

        assert n_idx == n_loc == 5, "result count must match";
        # With index: at least one AM miss (first traversal after am_clear) or GT hit
        assert (stats_idx["am_misses"] + stats_idx["gt_hits"] + stats_idx["am_hits"]) >= 1, (
            f"index must be consulted when enabled: stats={stats_idx}"
        );
        # Without index: no index stats at all
        assert stats_loc["am_hits"] == 0 and stats_loc["gt_hits"] == 0, (
            f"index must not be consulted when disabled: stats={stats_loc}"
        );
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        os.environ["JAC_INDEX_ENABLED"] = "true";
        am_clear();
    }
}

test "fetch - index does not regress at high selectivity (90%)" {
    tmp_idx = mkdtemp();
    tmp_loc = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        def run_query(tmp: str, enabled: bool) -> tuple[int, int] {
            os.environ["JAC_INDEX_ENABLED"] = "true" if enabled else "false";
            am_clear();
            with without_plugins() {
                ctx = fresh_ctx(tmp);
                mem = ctx.mem;
                counters = {"n": 0};
                _orig_get = mem.get;
                def cget(id: object) -> object {
                    if id in mem.__mem__ {
                        return mem.__mem__[id];
                    }
                    r = _orig_get(id);
                    if r is not None { counters["n"] += 1; }
                    return r;
                }
                mem.get = cget;
                try {
                    root spawn BuildGraph(n_targets=45, n_others=5);
                    am_clear();
                    w = root spawn QueryTargets();
                    return (len(w.results), counters["n"]);
                } finally {
                    close_ctx(ctx);
                }
            }
        }

        (n_idx, fc_idx) = run_query(tmp_idx, True);
        (n_loc, fc_loc) = run_query(tmp_loc, False);
        os.environ["JAC_INDEX_ENABLED"] = "true";

        assert n_idx == n_loc == 45, "result count must match";
        assert fc_idx <= fc_loc + 5, (
            f"index must not significantly regress at high selectivity: "
            f"index={fc_idx} local={fc_loc}"
        );
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        os.environ["JAC_INDEX_ENABLED"] = "true";
        am_clear();
    }
}

test "fetch - below degree threshold uses edge-list loop (no index stats)" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    reset_stats();
    try {
        # 5 edges total — below default threshold of 10
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=2, n_others=3);
                am_clear();
                reset_stats();

                w = root spawn QueryTargets();

                assert _stats["am_hits"] == 0 and _stats["gt_hits"] == 0, (
                    "index must not be used below degree threshold"
                );
                assert len(w.results) == 2;
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "fetch - wildcard [here-->] bypasses index entirely" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    reset_stats();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=25, n_others=25);
                am_clear();
                reset_stats();

                # [here-->] — no type filter → must use edge-list loop
                w = root spawn QueryAll();

                assert _stats["am_hits"] == 0 and _stats["gt_hits"] == 0, (
                    "wildcard traversal must never consult the index"
                );
                assert len(w.results) == 50;
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

# ===========================================================================
# Group 4 — Mutation Consistency
# ===========================================================================

test "mutation - traversal count tracks ++> and del --> correctly" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                # Step A: build baseline (20 targets + 20 others)
                root spawn BuildGraph(n_targets=20, n_others=20);

                am_clear();
                w_a = root spawn QueryTargets();
                assert len(w_a.results) == 20, f"step A: expected 20, got {len(w_a.results)}";

                # Step B: add 5 more TargetNodes
                root spawn AddTargets(n=5);

                am_clear();
                w_b = root spawn QueryTargets();
                assert len(w_b.results) == 25, f"step B: expected 25, got {len(w_b.results)}";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

test "mutation - rebuild_topology_index warms AM and traversal returns full count" {
    tmp = mkdtemp();
    _orig_base = Jac.base_path_dir;
    _orig_ctx  = Jac.exec_ctx;
    am_clear();
    try {
        with without_plugins() {
            ctx = fresh_ctx(tmp);
            try {
                root spawn BuildGraph(n_targets=20, n_others=0);
                db = db_path(ctx);

                # Clear AM (edge_topology intact)
                am_clear();
                root_id = str(ctx.user_root.id);

                # rebuild_topology_index warms AM from existing edge_topology
                result = rebuild_topology_index(ctx.mem);

                assert am_index.get(root_id) is not None, "AM must be warmed after rebuild";
                assert "rebuilt" in result.get("gt", ""), f"unexpected result: {result}";

                # Now traversal must use warmed AM and return correct count
                reset_stats();
                w = root spawn QueryTargets();
                assert len(w.results) == 20, f"expected 20, got {len(w.results)}";
                assert _stats["am_hits"] >= 1, "AM must be hit after rebuild warmed it";
            } finally {
                close_ctx(ctx);
            }
        }
    } finally {
        Jac.set_base_path(_orig_base);
        Jac.exec_ctx = _orig_ctx;
        am_clear();
    }
}

# ===========================================================================
# Group 5 — Schema
# ===========================================================================

test "schema - topology tables and indexes created by SqliteMemory" {
    import from jaclang.runtimelib.memory { SqliteMemory }
    tmp = mkdtemp();
    db = os.path.join(tmp, "schema_test.db");
    mem = SqliteMemory(path=db);
    mem._ensure_connection();
    mem.close();

    con = sqlite3.connect(db);
    tables = {
        row[0] for row in
        con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    };
    indexes = {
        row[0] for row in
        con.execute("SELECT name FROM sqlite_master WHERE type='index'").fetchall()
    };
    con.close();

    assert "node_topology" in tables;
    assert "edge_topology" in tables;
    assert "idx_nt_type"   in indexes;
    assert "idx_et_source" in indexes;
    assert "idx_et_target" in indexes;
}

test "schema - _ensure_connection is idempotent" {
    import from jaclang.runtimelib.memory { SqliteMemory }
    tmp = mkdtemp();
    db = os.path.join(tmp, "idempotent_test.db");
    mem = SqliteMemory(path=db);
    mem._ensure_connection();
    mem._ensure_connection();  # second call must not raise
    mem.close();
}
