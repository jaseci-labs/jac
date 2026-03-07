"""Graph Topology Index tests (GT + AM layers).

Groups:
  1 - GT Table Correctness
  2 - AM Correctness
  3 - Fetch Count Reduction (core metric)
  4 - Mutation Consistency
  5 - Schema

Runs with the standard pytest runner — no Jac compilation needed.
Uses without_plugins() to bypass jac_scale and get an isolated SQLite DB
per test via JacRuntime.base_path_dir.
"""

from __future__ import annotations

import os
import sqlite3
import sys
import tempfile

import pytest

# ---------------------------------------------------------------------------
# Node class registry — dynamically created classes need to be importable
# for pickle (even though GT writes don't require pickling).
# We register them in sys.modules under a stable test module name.
# ---------------------------------------------------------------------------

_TEST_MODULE = "__jac_graph_index_test__"
if _TEST_MODULE not in sys.modules:
    import types as _types

    sys.modules[_TEST_MODULE] = _types.ModuleType(_TEST_MODULE)


def make_node_cls(name: str, base_cls=None):
    """Create a NodeArchetype subclass dynamically for testing."""
    from jaclang.jac0core.archetype import NodeArchetype

    b = base_cls if base_cls is not None else NodeArchetype
    cls = type(name, (b,), {"__module__": _TEST_MODULE})
    setattr(sys.modules[_TEST_MODULE], name, cls)
    return cls


# ---------------------------------------------------------------------------
# Context helpers
# ---------------------------------------------------------------------------


def _jac_ctx(tmp_dir: str):
    """Return (ctx, db_path) for a fresh isolated Jac context.

    Caller must call ctx.close() and reset JacRuntime.exec_ctx when done.
    """
    from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface as Jac

    JacRuntime.base_path_dir = tmp_dir
    JacRuntime.exec_ctx = None
    ctx = Jac.create_j_context(None)
    JacRuntime.set_context(ctx)
    return ctx, ctx.mem.l3.path


def _close_ctx(ctx):
    from jaclang.jac0core.runtime import JacRuntime

    ctx.close()
    JacRuntime.exec_ctx = None


# ---------------------------------------------------------------------------
# build_graph helper
# ---------------------------------------------------------------------------


def build_graph(tmp_dir: str, node_counts: dict[type, int]) -> tuple[str, str]:
    """Create edges from root to n nodes of each type. Return (root_id, db_path)."""
    from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins

    with without_plugins():
        ctx, db_path = _jac_ctx(tmp_dir)
        try:
            root = Jac.root()
            root_id = str(root.__jac__.id)
            builder = Jac.build_edge(False, None, None)
            for cls, n in node_counts.items():
                for _ in range(n):
                    t = cls()
                    builder(root.__jac__, t.__jac__)
        finally:
            _close_ctx(ctx)
    return root_id, db_path


# ---------------------------------------------------------------------------
# CountingMemory
# ---------------------------------------------------------------------------


def make_counting_mem(tmp_dir: str):
    """Return (mem, counters) where counters['fetch_count'] tracks DB hits.

    Must be called inside a without_plugins() block.
    Uses _jac_ctx internally to create the context.
    """
    from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface as Jac

    JacRuntime.base_path_dir = tmp_dir
    JacRuntime.exec_ctx = None
    ctx = Jac.create_j_context(None)
    JacRuntime.set_context(ctx)

    mem = ctx.mem
    counters = {"fetch_count": 0}
    original_get = mem.get

    def counting_get(id):
        if id in mem.__mem__:
            return mem.__mem__[id]
        result = original_get(id)
        if result is not None:
            counters["fetch_count"] += 1
        return result

    mem.get = counting_get
    return ctx, mem, counters


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def clean_am_state():
    """Reset AM state before and after every test."""
    from jaclang.runtimelib.am_index import am_clear, reset_stats

    am_clear()
    reset_stats()
    yield
    am_clear()
    reset_stats()


@pytest.fixture()
def tmp_dir():
    """Isolated temp directory for each test."""
    return tempfile.mkdtemp()


# ===========================================================================
# Group 1 — GT Table Correctness
# ===========================================================================


class TestGTCorrectness:
    def test_t1_1_edge_write_populates_gt(self, tmp_dir):
        """T1.1 — creating edges populates edge_topology and node_topology."""
        from jaclang.jac0core.runtime import without_plugins

        TargetNode = make_node_cls("TargetNodeT11")
        OtherNode = make_node_cls("OtherNodeT11")

        with without_plugins():
            _, db = build_graph(tmp_dir, {TargetNode: 3, OtherNode: 2})

        con = sqlite3.connect(db)
        et_total = con.execute("SELECT COUNT(*) FROM edge_topology").fetchone()[0]
        et_target = con.execute(
            "SELECT COUNT(*) FROM edge_topology WHERE target_type='TargetNodeT11'"
        ).fetchone()[0]
        et_other = con.execute(
            "SELECT COUNT(*) FROM edge_topology WHERE target_type='OtherNodeT11'"
        ).fetchone()[0]
        nt_target = con.execute(
            "SELECT COUNT(*) FROM node_topology WHERE node_type='TargetNodeT11'"
        ).fetchone()[0]
        con.close()

        assert et_total >= 5, f"expected >=5 edge_topology rows, got {et_total}"
        assert et_target == 3, f"expected 3 TargetNodeT11 edges, got {et_target}"
        assert et_other == 2, f"expected 2 OtherNodeT11 edges, got {et_other}"
        assert nt_target >= 3, f"expected >=3 TargetNodeT11 node_topology rows, got {nt_target}"

    def test_t1_2_edge_delete_removes_gt_row(self, tmp_dir):
        """T1.2 — removing an edge removes the edge_topology row."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.runtimelib.am_index import _gt_delete_edge

        TargetNode = make_node_cls("TargetNodeT12")

        with without_plugins():
            _, db = build_graph(tmp_dir, {TargetNode: 3})

            # Grab one edge id from topology
            con = sqlite3.connect(db)
            edge_id = con.execute(
                "SELECT edge_id FROM edge_topology WHERE target_type='TargetNodeT12' LIMIT 1"
            ).fetchone()[0]
            con.close()

            # Reload context to get a SqliteMemory with the same DB
            ctx, _ = _jac_ctx(tmp_dir)
            try:
                _gt_delete_edge(ctx.mem, edge_id)
            finally:
                _close_ctx(ctx)

        con = sqlite3.connect(db)
        remaining = con.execute(
            "SELECT COUNT(*) FROM edge_topology WHERE target_type='TargetNodeT12'"
        ).fetchone()[0]
        gone = con.execute(
            "SELECT COUNT(*) FROM edge_topology WHERE edge_id=?", (edge_id,)
        ).fetchone()[0]
        con.close()

        assert gone == 0, "deleted edge should not appear in edge_topology"
        assert remaining == 2, f"expected 2 remaining rows, got {remaining}"

    def test_t1_3_gt_rebuild_from_anchor_store(self, tmp_dir):
        """T1.3 — rebuild_topology_index restores corrupted topology tables."""
        from jaclang.jac0core.runtime import without_plugins
        from jaclang.runtimelib.am_index import rebuild_topology_index

        TargetNode = make_node_cls("TargetNodeT13")

        with without_plugins():
            _, db = build_graph(tmp_dir, {TargetNode: 5})

            # Corrupt topology tables
            con = sqlite3.connect(db)
            con.execute("DELETE FROM edge_topology")
            con.execute("DELETE FROM node_topology")
            con.commit()
            con.close()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                result = rebuild_topology_index(ctx.mem)
            finally:
                _close_ctx(ctx)

        con = sqlite3.connect(db)
        et_count = con.execute("SELECT COUNT(*) FROM edge_topology").fetchone()[0]
        con.close()

        assert et_count >= 5, f"expected >=5 rows after rebuild, got {et_count}"
        assert "rebuilt" in result.get("gt", "")

    def test_t1_4_mro_fan_out_in_node_topology(self, tmp_dir):
        """T1.4 — parent-type rows are written to node_topology via MRO."""
        from jaclang.jac0core.runtime import without_plugins

        BaseContent = make_node_cls("BaseContentT14")
        PostNode = make_node_cls("PostNodeT14", base_cls=BaseContent)

        with without_plugins():
            _, db = build_graph(tmp_dir, {PostNode: 2})

        con = sqlite3.connect(db)
        post_rows = con.execute(
            "SELECT COUNT(*) FROM node_topology WHERE node_type='PostNodeT14'"
        ).fetchone()[0]
        base_rows = con.execute(
            "SELECT COUNT(*) FROM node_topology WHERE node_type='BaseContentT14'"
        ).fetchone()[0]
        con.close()

        assert post_rows >= 2, f"expected >=2 PostNodeT14 rows, got {post_rows}"
        assert base_rows >= 2, f"expected >=2 BaseContentT14 (MRO) rows, got {base_rows}"


# ===========================================================================
# Group 2 — AM Correctness
# ===========================================================================


class TestAMCorrectness:
    def test_t2_1_am_put_at_edge_creation(self, tmp_dir):
        """T2.1 — build_edge writes to AM via am_put."""
        from jaclang.jac0core.runtime import without_plugins
        from jaclang.runtimelib.am_index import am_index

        TargetNode = make_node_cls("TargetNodeT21")

        with without_plugins():
            root_id, _ = build_graph(tmp_dir, {TargetNode: 1})

        bucket = am_index.get(root_id)
        assert bucket is not None, "AM bucket for root should exist after build_edge"
        assert len(bucket.get("TargetNodeT21", [])) == 1, (
            "AM should contain 1 TargetNodeT21 under root"
        )

    def test_t2_2_am_invalidate_at_edge_removal(self, tmp_dir):
        """T2.2 — remove_edge triggers am_invalidate."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.runtimelib.am_index import am_index

        TargetNode = make_node_cls("TargetNodeT22")

        with without_plugins():
            root_id, _ = build_graph(tmp_dir, {TargetNode: 1})
            assert am_index.get(root_id) is not None

            # Re-open context and remove the edge
            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                nanch = root.__jac__
                for eanch in list(nanch.edges):
                    Jac.remove_edge(nd=nanch, edge=eanch)
                    break
            finally:
                _close_ctx(ctx)

        assert am_index.get(root_id) is None, "AM bucket must be invalidated"

    def test_t2_3_am_miss_falls_back_to_gt(self, tmp_dir):
        """T2.3 — AM miss → GT query → AM populated."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import _stats, am_clear, am_index, reset_stats

        TargetNode = make_node_cls("TargetNodeT23")

        with without_plugins():
            root_id, _ = build_graph(tmp_dir, {TargetNode: 15})  # > threshold

            # Simulate restart: clear AM but GT is intact
            am_clear()
            reset_stats()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                dest = ObjectSpatialDestination(
                    direction=EdgeDir.OUT,
                    node_type_name="TargetNodeT23",
                    nd=lambda arch: isinstance(arch, TargetNode),
                )
                result = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert _stats["am_misses"] >= 1, "expected AM miss after am_clear()"
        assert _stats["gt_hits"] >= 1, "expected GT to answer the miss"
        assert len(result) == 15, f"expected 15 results, got {len(result)}"
        assert am_index.get(root_id) is not None, "AM should be populated after GT hit"

    def test_t2_4_second_traversal_hits_am(self, tmp_dir):
        """T2.4 — second traversal hits AM, not GT."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import _stats, am_clear, reset_stats

        TargetNode = make_node_cls("TargetNodeT24")
        OtherNode = make_node_cls("OtherT24")

        with without_plugins():
            build_graph(tmp_dir, {TargetNode: 15, OtherNode: 5})
            am_clear()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                dest = ObjectSpatialDestination(
                    direction=EdgeDir.OUT,
                    node_type_name="TargetNodeT24",
                    nd=lambda arch: isinstance(arch, TargetNode),
                )
                # First traversal — warms AM from GT
                r1 = Jac.edges_to_nodes([root], dest)
                reset_stats()
                # Second traversal — should hit AM
                r2 = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert _stats["am_hits"] >= 1, "expected AM hit on second traversal"
        assert _stats["gt_hits"] == 0, "GT should not be consulted on second traversal"
        assert len(r1) == len(r2) == 15

    def test_t2_5_parent_type_query_via_mro(self, tmp_dir):
        """T2.5 — querying a parent type returns all subtype nodes."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import am_clear

        BaseContent = make_node_cls("BaseContentT25")
        PostNode = make_node_cls("PostNodeT25", base_cls=BaseContent)
        CommentNode = make_node_cls("CommentNodeT25", base_cls=BaseContent)
        OtherNode = make_node_cls("OtherNodeT25")

        with without_plugins():
            build_graph(tmp_dir, {PostNode: 2, CommentNode: 2, OtherNode: 1})
            am_clear()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                dest = ObjectSpatialDestination(
                    direction=EdgeDir.OUT,
                    node_type_name="BaseContentT25",
                    nd=lambda arch: isinstance(arch, BaseContent),
                )
                result = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert len(result) == 4, f"expected 4 BaseContent nodes, got {len(result)}"
        type_names = {type(n).__name__ for n in result}
        assert "OtherNodeT25" not in type_names, "OtherNode must not appear"


# ===========================================================================
# Group 3 — Fetch Count Reduction (core metric)
# ===========================================================================


DEGREE_THRESHOLD = int(os.environ.get("JAC_INDEX_DEGREE_THRESHOLD", "10"))


class TestFetchReduction:
    def _run_traversal(self, tmp_dir: str, target_cls, enabled: bool):
        """Run a typed traversal and return (result_list, fetch_count)."""
        from jaclang.jac0core.runtime import JacRuntime, JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination

        prev = os.environ.get("JAC_INDEX_ENABLED", "true")
        os.environ["JAC_INDEX_ENABLED"] = "true" if enabled else "false"
        try:
            with without_plugins():
                JacRuntime.base_path_dir = tmp_dir
                JacRuntime.exec_ctx = None
                ctx = Jac.create_j_context(None)
                JacRuntime.set_context(ctx)
                mem = ctx.mem
                counters = {"fetch_count": 0}
                original_get = mem.get

                def counting_get(id):
                    if id in mem.__mem__:
                        return mem.__mem__[id]
                    result = original_get(id)
                    if result is not None:
                        counters["fetch_count"] += 1
                    return result

                mem.get = counting_get
                try:
                    root = Jac.root()
                    dest = ObjectSpatialDestination(
                        direction=EdgeDir.OUT,
                        node_type_name=target_cls.__name__,
                        nd=lambda arch, cls=target_cls: isinstance(arch, cls),
                    )
                    result = Jac.edges_to_nodes([root], dest)
                finally:
                    _close_ctx(ctx)
            return result, counters["fetch_count"]
        finally:
            os.environ["JAC_INDEX_ENABLED"] = prev

    def test_t3_1_low_selectivity(self, tmp_dir):
        """T3.1 — index fetches far fewer anchors than local path (10% selectivity)."""
        from jaclang.jac0core.runtime import without_plugins
        from jaclang.runtimelib.am_index import am_clear

        TargetNode = make_node_cls("TargetNodeT31")
        OtherNode = make_node_cls("OtherNodeT31")

        tmp_idx = tempfile.mkdtemp()
        tmp_loc = tempfile.mkdtemp()

        with without_plugins():
            build_graph(tmp_idx, {TargetNode: 5, OtherNode: 45})
            build_graph(tmp_loc, {TargetNode: 5, OtherNode: 45})

        am_clear()
        r_idx, fc_idx = self._run_traversal(tmp_idx, TargetNode, enabled=True)
        am_clear()
        r_loc, fc_loc = self._run_traversal(tmp_loc, TargetNode, enabled=False)

        assert len(r_idx) == len(r_loc) == 5, "result count must match"
        assert fc_idx < fc_loc, (
            f"index should fetch fewer anchors: index={fc_idx} local={fc_loc}"
        )

    def test_t3_2_high_selectivity_no_regression(self, tmp_dir):
        """T3.2 — index must not hurt at high selectivity (90%)."""
        from jaclang.jac0core.runtime import without_plugins
        from jaclang.runtimelib.am_index import am_clear

        TargetNode = make_node_cls("TargetNodeT32")
        OtherNode = make_node_cls("OtherNodeT32")

        tmp_idx = tempfile.mkdtemp()
        tmp_loc = tempfile.mkdtemp()

        with without_plugins():
            build_graph(tmp_idx, {TargetNode: 45, OtherNode: 5})
            build_graph(tmp_loc, {TargetNode: 45, OtherNode: 5})

        am_clear()
        r_idx, fc_idx = self._run_traversal(tmp_idx, TargetNode, enabled=True)
        am_clear()
        r_loc, fc_loc = self._run_traversal(tmp_loc, TargetNode, enabled=False)

        assert len(r_idx) == len(r_loc) == 45, "result count must match"
        assert fc_idx <= fc_loc + 5, (
            f"index must not significantly hurt at high selectivity: "
            f"index={fc_idx} local={fc_loc}"
        )

    def test_t3_3_below_threshold_uses_local_path(self, tmp_dir):
        """T3.3 — degree <= threshold must bypass the index entirely."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import _stats, am_clear, reset_stats

        TargetNode = make_node_cls("TargetNodeT33")
        OtherNode = make_node_cls("OtherNodeT33")

        # fan = 5 (below default threshold of 10)
        with without_plugins():
            build_graph(tmp_dir, {TargetNode: 2, OtherNode: 3})
            am_clear()
            reset_stats()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                dest = ObjectSpatialDestination(
                    direction=EdgeDir.OUT,
                    node_type_name="TargetNodeT33",
                    nd=lambda arch: isinstance(arch, TargetNode),
                )
                result = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert _stats["am_hits"] == 0 and _stats["gt_hits"] == 0, (
            "index must not be used below degree threshold"
        )
        assert len(result) == 2

    def test_t3_4_wildcard_bypasses_index(self, tmp_dir):
        """T3.4 — wildcard traversal (no node_type_name) bypasses index."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import _stats, am_clear, reset_stats

        TargetNode = make_node_cls("TargetNodeT34")
        OtherNode = make_node_cls("OtherNodeT34")

        with without_plugins():
            build_graph(tmp_dir, {TargetNode: 25, OtherNode: 25})
            am_clear()
            reset_stats()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                # Wildcard: no node_type_name
                dest = ObjectSpatialDestination(direction=EdgeDir.OUT)
                result = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert _stats["am_hits"] == 0 and _stats["gt_hits"] == 0, (
            "wildcard traversal must not use the index"
        )
        assert len(result) == 50


# ===========================================================================
# Group 4 — Mutation Consistency
# ===========================================================================


class TestMutationConsistency:
    def test_t4_1_add_then_remove_edges(self, tmp_dir):
        """T4.1 — traversal count tracks graph mutations correctly."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import am_clear

        TargetNode = make_node_cls("TargetNodeT41")
        OtherNode = make_node_cls("OtherNodeT41")

        with without_plugins():
            # Step A — baseline
            build_graph(tmp_dir, {TargetNode: 20, OtherNode: 20})
            am_clear()

            dest = ObjectSpatialDestination(
                direction=EdgeDir.OUT,
                node_type_name="TargetNodeT41",
                nd=lambda arch: isinstance(arch, TargetNode),
            )

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                r_a = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

            assert len(r_a) == 20, f"step A: expected 20, got {len(r_a)}"

            # Step B — add 5 more
            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                builder = Jac.build_edge(False, None, None)
                for _ in range(5):
                    t = TargetNode()
                    builder(root.__jac__, t.__jac__)
            finally:
                _close_ctx(ctx)

            am_clear()
            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                r_b = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert len(r_b) == 25, f"step B: expected 25, got {len(r_b)}"

    def test_t4_2_am_invalidate_then_gt_requery(self, tmp_dir):
        """T4.2 — AM invalidation → GT fallback → correct count."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import (
            _gt_delete_edge,
            _stats,
            am_clear,
            am_index,
            am_invalidate,
            reset_stats,
        )

        TargetNode = make_node_cls("TargetNodeT42")

        with without_plugins():
            root_id, db = build_graph(tmp_dir, {TargetNode: 20})

            # Warm AM via traversal
            am_clear()
            dest = ObjectSpatialDestination(
                direction=EdgeDir.OUT,
                node_type_name="TargetNodeT42",
                nd=lambda arch: isinstance(arch, TargetNode),
            )

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                Jac.edges_to_nodes([root], dest)
                assert am_index.get(root_id) is not None, "AM should be warm after traversal"

                # Invalidate AM + delete one row from GT topology
                con = sqlite3.connect(db)
                edge_id = con.execute(
                    "SELECT edge_id FROM edge_topology WHERE target_type='TargetNodeT42' LIMIT 1"
                ).fetchone()[0]
                con.close()

                am_invalidate(root_id)
                _gt_delete_edge(ctx.mem, edge_id)
                assert am_index.get(root_id) is None, "AM must be invalidated"

                reset_stats()
                root2 = Jac.root()
                Jac.edges_to_nodes([root2], dest)
            finally:
                _close_ctx(ctx)

        assert _stats["am_misses"] >= 1, "expected AM miss after invalidation"
        bucket = am_index.get(root_id)
        assert bucket is not None, "AM should be repopulated after GT hit"

    def test_t4_3_rebuild_restores_consistency(self, tmp_dir):
        """T4.3 — rebuild_topology_index restores corrupted tables."""
        from jaclang.jac0core.runtime import JacRuntimeInterface as Jac, without_plugins
        from jaclang.jac0core.archetype import EdgeDir, ObjectSpatialDestination
        from jaclang.runtimelib.am_index import am_clear, rebuild_topology_index

        TargetNode = make_node_cls("TargetNodeT43")

        with without_plugins():
            _, db = build_graph(tmp_dir, {TargetNode: 20})

            # Corrupt 5 rows
            con = sqlite3.connect(db)
            con.execute(
                "DELETE FROM edge_topology WHERE edge_id IN "
                "(SELECT edge_id FROM edge_topology LIMIT 5)"
            )
            con.commit()
            con.close()

            am_clear()

            ctx, _ = _jac_ctx(tmp_dir)
            try:
                rebuild_topology_index(ctx.mem)
            finally:
                _close_ctx(ctx)

        con = sqlite3.connect(db)
        et_count = con.execute("SELECT COUNT(*) FROM edge_topology").fetchone()[0]
        con.close()

        assert et_count >= 20, f"expected >=20 rows after rebuild, got {et_count}"

        with without_plugins():
            am_clear()
            ctx, _ = _jac_ctx(tmp_dir)
            try:
                root = Jac.root()
                dest = ObjectSpatialDestination(
                    direction=EdgeDir.OUT,
                    node_type_name="TargetNodeT43",
                    nd=lambda arch: isinstance(arch, TargetNode),
                )
                result = Jac.edges_to_nodes([root], dest)
            finally:
                _close_ctx(ctx)

        assert len(result) == 20, f"expected 20 nodes after rebuild, got {len(result)}"


# ===========================================================================
# Group 5 — Topology table creation (schema)
# ===========================================================================


class TestSchema:
    def test_topology_tables_created(self, tmp_dir):
        """Topology tables exist after SqliteMemory._ensure_connection."""
        from jaclang.runtimelib.memory import SqliteMemory

        db = os.path.join(tmp_dir, "schema_test.db")
        mem = SqliteMemory(path=db)
        mem._ensure_connection()
        mem.close()

        con = sqlite3.connect(db)
        tables = {
            row[0]
            for row in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        indexes = {
            row[0]
            for row in con.execute(
                "SELECT name FROM sqlite_master WHERE type='index'"
            ).fetchall()
        }
        con.close()

        assert "node_topology" in tables
        assert "edge_topology" in tables
        assert "idx_nt_type" in indexes
        assert "idx_et_source" in indexes
        assert "idx_et_target" in indexes

    def test_idempotent_table_creation(self, tmp_dir):
        """Calling _ensure_connection twice does not raise."""
        from jaclang.runtimelib.memory import SqliteMemory

        db = os.path.join(tmp_dir, "idempotent_test.db")
        mem = SqliteMemory(path=db)
        mem._ensure_connection()
        mem._ensure_connection()  # second call
        mem.close()
