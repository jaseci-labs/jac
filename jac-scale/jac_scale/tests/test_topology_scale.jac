"""End-to-end test: topology index survives persistence round-trip.

Validates that when a graph is built with topology_index enabled, the index
data on root's NodeAnchor survives serialization via the Serializer (the same
path used by MongoDB/SQLite backends) and deserialization back — so type-filtered
edge queries work after reload without rebuilding.
"""

import os;
import sys;
import shutil;
import subprocess;
import from tempfile { mkdtemp }
import from uuid { UUID }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.archetype { NodeAnchor }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.topology_index { TopologyIndex }
import from jaclang.project.config { JacConfig, set_config }

node Person {
    has name: str = "",
        age: int = 0;
}

node City {
    has name: str = "";
}

edge Knows {}
edge LivesIn {}

"""Serializer round-trip: topology_index_data bytes must survive serialize/deserialize."""
test "topology_index_data survives Serializer round-trip" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.get_base_path_dir();
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;

        for i in range(5) {
            r +>: Knows :+> Person(name=f"person_{i}", age=20 + i);
        }
        for i in range(3) {
            r +>: LivesIn :+> City(name=f"city_{i}");
        }

        # Verify index was built
        idx_before = r.__jac__.get_topology_index();
        assert isinstance(idx_before, TopologyIndex) , "Index should exist after building graph";
        assert len(idx_before) > 0 , "Index should have edges";

        # Serialize the root anchor (same path as MongoBackend.put)
        serialized = Serializer.serialize(r.__jac__, include_type=True);

        # Deserialize (same path as MongoBackend._load_anchor)
        restored = Serializer.deserialize(serialized);

        assert isinstance(restored, NodeAnchor) , "Should deserialize as NodeAnchor";

        # THE KEY ASSERTION: topology_index_data must survive
        idx_after = restored.get_topology_index();
        assert isinstance(idx_after, TopologyIndex) , (
            "Topology index should survive Serializer round-trip. "
            "Got topology_index_data=" + str(restored.topology_index_data)
        );
        assert len(idx_after.node_table) == len(idx_before.node_table) , (
            f"Node count mismatch: {len(idx_after.node_table)} vs {len(
                idx_before.node_table
            )}"
        );
        assert len(idx_after.adj_list) == len(idx_before.adj_list) , (
            f"Edge count mismatch: {len(idx_after.adj_list)} vs {len(
                idx_before.adj_list
            )}"
        );

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

"""After serialize/deserialize, resolve_chain should still work correctly."""
test "topology index resolve_chain works after Serializer round-trip" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.get_base_path_dir();
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;

        for i in range(10) {
            r +>: Knows :+> Person(name=f"p{i}", age=i);
        }
        for i in range(5) {
            r +>: LivesIn :+> City(name=f"c{i}");
        }

        root_id = r.__jac__.id;

        # Serialize and restore
        serialized = Serializer.serialize(r.__jac__, include_type=True);
        restored = Serializer.deserialize(serialized);
        idx = restored.get_topology_index();

        assert isinstance(idx, TopologyIndex) , "Index should survive round-trip";

        # resolve_chain should narrow correctly
        person_ids = idx.resolve_chain({root_id}, [("Knows", "Person", 2)]);
        assert len(person_ids) == 10 , f"Expected 10 person IDs, got {len(person_ids)}";

        city_ids = idx.resolve_chain({root_id}, [("LivesIn", "City", 2)]);
        assert len(city_ids) == 5 , f"Expected 5 city IDs, got {len(city_ids)}";

        # Non-existent type should return empty
        empty = idx.resolve_chain({root_id}, [("Knows", "City", 2)]);
        assert len(empty) == 0 , f"Expected 0 for wrong type, got {len(empty)}";

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

"""Full persistence: build graph, save to SQLite, reload, verify index + queries."""
test "topology index survives sqlite persistence round-trip" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.get_base_path_dir();
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);

        # --- Phase 1: Build graph and persist ---
        ctx1 = ExecutionContext();
        JacRuntime.set_context(ctx1);

        r = root;

        for i in range(5) {
            r +>: Knows :+> Person(name=f"person_{i}", age=20 + i);
        }
        for i in range(3) {
            r +>: LivesIn :+> City(name=f"city_{i}");
        }

        # Verify queries work before persistence
        persons_before = [r->:Knows:->[?:Person]];
        assert len(persons_before) == 5 , f"Expected 5 persons, got {len(
            persons_before
        )}";
        cities_before = [r->:LivesIn:->[?:City]];
        assert len(cities_before) == 3 , f"Expected 3 cities, got {len(cities_before)}";

        root_id = r.__jac__.id;
        idx_before = r.__jac__.get_topology_index();
        edge_count = len(idx_before.adj_list);
        node_count = len(idx_before.node_table);

        # Commit to SQLite
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: Fresh context, reload from SQLite ---
        ctx2 = ExecutionContext();
        JacRuntime.set_context(ctx2);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None , "Root should be loadable from SQLite";

        r2 = root_anchor.archetype;

        # Verify topology index survived the round-trip
        idx_after = root_anchor.get_topology_index();
        assert isinstance(idx_after, TopologyIndex) , (
            "Topology index should survive SQLite round-trip"
        );
        assert len(idx_after.adj_list) == edge_count , (
            f"Edge count mismatch: {len(idx_after.adj_list)} vs {edge_count}"
        );
        assert len(idx_after.node_table) == node_count , (
            f"Node count mismatch: {len(idx_after.node_table)} vs {node_count}"
        );

        # Verify type-filtered queries work with restored index
        persons_after = [r2->:Knows:->[?:Person]];
        assert len(persons_after) == 5 , f"Expected 5 persons after reload, got {len(
            persons_after
        )}";

        cities_after = [r2->:LivesIn:->[?:City]];
        assert len(cities_after) == 3 , f"Expected 3 cities after reload, got {len(
            cities_after
        )}";

        # Verify data integrity
        person_names = sorted([p.name for p in persons_after]);
        assert person_names == [f"person_{i}" for i in range(5)] , (
            f"Person names mismatch: {person_names}"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

"""Regression (#6388): a topology-only change must alter the dirty-check hash.

`Serializer._compute_hash` is the gate the jac-scale backends use to decide
whether an anchor is dirty and needs persisting (`MongoBackend.sync` and
`ScaleTieredMemory.commit`). The topology index lives on the root anchor as
`topology_index_data` and is updated by `on_edge_created` for edges anywhere in
the subtree — without touching the root's own edges or archetype fields. If the
hash ignores `topology_index_data`, such a change is invisible to the gate, the
root is judged clean, and the updated index is never written to MongoDB.

This fails when `_compute_hash` strips `topology_index_data` before hashing.
"""
test "topology-only change is detected by _compute_hash dirty gate" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.get_base_path_dir();
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;

        # Build an initial graph so the root carries a populated topology index.
        p0 = Person(name="p0", age=20);
        r +>: Knows :+> p0;
        for i in range(1, 4) {
            r +>: Knows :+> Person(name=f"p{i}", age=20 + i);
        }

        root_anchor = r.__jac__;
        idx_before = root_anchor.get_topology_index();
        assert len(idx_before) > 0 , "Root should carry a topology index";

        # Snapshot the dirty-gate hash and the raw index blob for the baseline.
        baseline_hash = Serializer._compute_hash(root_anchor);
        topo_before = root_anchor.topology_index_data;
        root_edges_before = [e.id for e in root_anchor.edges];

        # A topology-only mutation: connect an edge *deeper* in the subtree
        # (p0 -> Person). on_edge_created updates the root's topology index, but
        # the root's own edge list and archetype fields are untouched.
        p0 +>: Knows :+> Person(name="deep", age=99);

        topo_after = root_anchor.topology_index_data;
        root_edges_after = [e.id for e in root_anchor.edges];

        # Preconditions: the index blob changed, but nothing else on the root did.
        assert topo_after != topo_before , (
            "Precondition: deep edge must update the root's topology_index_data"
        );
        assert root_edges_after == root_edges_before , (
            "Precondition: a deep edge must not change the root's own edge list"
        );

        # The fix: that topology change must be visible to the dirty gate.
        after_hash = Serializer._compute_hash(root_anchor);
        assert after_hash != baseline_hash , (
            "topology_index_data must participate in _compute_hash; otherwise a "
            "topology change leaves the root judged clean and the updated index "
            "is never persisted (#6388)"
        );

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

# Standalone script run as separate OS processes (one per phase), so each phase
# reloads the graph from SQLite with zero in-memory carry-over — a true
# persistence round-trip across a "restart". `build` and `deep` each auto-commit
# on exit; `check` reads the reloaded index. A deep edge (p0 -> deep) updates the
# root's topology index without touching the root's own edges/archetype, which
# is exactly the topology-only change the SQLite dirty gate must catch.
glob TOPO_REGRESS_SCRIPT: str = "import os;\n"
     "\n"
     "node Person { has name: str = \"\"; }\n"
     "edge Knows {}\n"
     "\n"
     "with entry {\n"
     "    phase = os.environ.get(\"PHASE\", \"\");\n"
     "    r = root;\n"
     "    if phase == \"build\" {\n"
     "        r +>: Knows :+> Person(name=\"p0\");\n"
     "    } elif phase == \"deep\" {\n"
     "        p0 = [r ->: Knows :-> [?:Person]][0];\n"
     "        p0 +>: Knows :+> Person(name=\"deep\");\n"
     "        print(\"DEEP_NODES=\" + str(len(r.__jac__.get_topology_index().node_table)));\n"
     "    } elif phase == \"check\" {\n"
     "        print(\"CHECK_NODES=\" + str(len(r.__jac__.get_topology_index().node_table)));\n"
     "    }\n"
     "}\n";

"""Run one phase of the regression script in a fresh `jac run` subprocess."""
def _topo_run_phase(workdir: str, phase: str) -> str {
    env = dict(os.environ);
    env["JAC_TOPOLOGY_INDEX"] = "1";
    env["PHASE"] = phase;
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", "regress.jac"],
        cwd=workdir,
        env=env,
        capture_output=True,
        text=True,
        timeout=600
    );
    return result.stdout;
}

"""Pull an integer marker (e.g. `DEEP_NODES=3`) out of captured stdout."""
def _topo_marker(out: str, prefix: str) -> int {
    for line in out.splitlines() {
        stripped = line.strip();
        if stripped.startswith(prefix) {
            return int(stripped[len(prefix):]);
        }
    }
    return -1;
}

"""Regression (#6388 sibling, SQLite): a topology-only change to an
already-persisted root must survive a process restart. SqliteMemory.sync keys
its dirty check off edge/access/archetype-field changes and never consults the
whole-anchor hash, so without persisting `topology_index_data` explicitly the
updated index is dropped and the reloaded index is stale. Process-isolated so
the result cannot be masked by in-memory carry-over.

Fails (check < deep) if SqliteMemory.sync does not persist topology_index_data.
"""
test "sqlite persists topology-only change across a process restart" {
    tmpdir = mkdtemp();
    try {
        script_path = os.path.join(tmpdir, "regress.jac");
        with open(script_path, "w") as f {
            f.write(TOPO_REGRESS_SCRIPT);
        }
        _topo_run_phase(tmpdir, "build");
        deep_out = _topo_run_phase(tmpdir, "deep");
        check_out = _topo_run_phase(tmpdir, "check");
        deep_nodes = _topo_marker(deep_out, "DEEP_NODES=");
        check_nodes = _topo_marker(check_out, "CHECK_NODES=");
        assert deep_nodes >= 3 , (
            "Precondition: deep edge should grow the in-memory index to >=3 "
            f"nodes, got {deep_nodes}. deep stdout:\n{deep_out}"
        );
        assert check_nodes == deep_nodes , (
            "Topology-only change was not persisted across the restart: "
            f"reloaded index has {check_nodes} nodes, expected {deep_nodes}. "
            f"check stdout:\n{check_out}"
        );
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}
