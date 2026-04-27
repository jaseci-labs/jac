"""End-to-end test: topology index survives persistence round-trip.

Validates that when a graph is built with topology_index enabled, the index
data on root's NodeAnchor survives serialization via the Serializer (the same
path used by MongoDB/SQLite backends) and deserialization back — so type-filtered
edge queries work after reload without rebuilding.
"""

import os;
import shutil;
import from tempfile { mkdtemp }
import from uuid { UUID }
import from jaclang { JacRuntimeInterface as Jac }
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
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);

        for i in range(5) {
            r +>: Knows :+> Person(name=f"person_{i}", age=20 + i);
        }
        for i in range(3) {
            r +>: LivesIn :+> City(name=f"city_{i}");
        }
        Jac.save(r);

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
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        r = root;
        Jac.save(r);

        for i in range(10) {
            r +>: Knows :+> Person(name=f"p{i}", age=i);
        }
        for i in range(5) {
            r +>: LivesIn :+> City(name=f"c{i}");
        }
        Jac.save(r);

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
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);

        # --- Phase 1: Build graph and persist ---
        ctx1 = ExecutionContext();
        JacRuntime.set_context(ctx1);

        r = root;
        Jac.save(r);

        for i in range(5) {
            r +>: Knows :+> Person(name=f"person_{i}", age=20 + i);
        }
        for i in range(3) {
            r +>: LivesIn :+> City(name=f"city_{i}");
        }
        Jac.save(r);

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
