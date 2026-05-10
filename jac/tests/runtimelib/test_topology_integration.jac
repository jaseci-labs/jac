"""Integration tests for topology index — config, instrumentation, serialization."""

import os;
import shutil;
import from tempfile { mkdtemp }
import from uuid { uuid4 }
import from jaclang.runtimelib.topology_index { TopologyIndex }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }


node _SliceLead {
    has idx: int = 0;
}

node _SliceOther {
    has idx: int = 0;
}

test "topology index config from toml" {
    import from jaclang.project.config { JacConfig }
    toml_str = "[project]\nname = \"test\"\n\n[run]\ntopology_index = false\n";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.run.topology_index is False;
}

test "JAC_TOPOLOGY_INDEX env var overrides toml" {
    # Eval workflows want to flip the index on/off without editing jac.toml.
    # JAC_TOPOLOGY_INDEX, when set, is authoritative; the config flag is the
    # fallback. Truthy values: 1 / true / yes / on (case-insensitive).
    import from jaclang.project.config { JacConfig, set_config }
    import from jaclang.runtimelib.topo_utils { _is_enabled }

    cfg_on = JacConfig();
    cfg_on.run.topology_index = True;
    cfg_off = JacConfig();
    cfg_off.run.topology_index = False;

    prev_env = os.environ.get("JAC_TOPOLOGY_INDEX");
    try {
        # No env → falls through to config.
        if "JAC_TOPOLOGY_INDEX" in os.environ {
            del os.environ["JAC_TOPOLOGY_INDEX"];
        }
        set_config(cfg_on);
        assert _is_enabled();
        set_config(cfg_off);
        assert not _is_enabled();

        # Env "off" overrides config=True.
        set_config(cfg_on);
        for off_val in ["0", "false", "FALSE", "off", "no", ""] {
            os.environ["JAC_TOPOLOGY_INDEX"] = off_val;
            assert not _is_enabled() , f"expected off for env={off_val!r}";
        }

        # Env "on" overrides config=False.
        set_config(cfg_off);
        for on_val in ["1", "true", "TRUE", "on", "yes", "On"] {
            os.environ["JAC_TOPOLOGY_INDEX"] = on_val;
            assert _is_enabled() , f"expected on for env={on_val!r}";
        }
    } finally {
        if prev_env is None {
            os.environ.pop("JAC_TOPOLOGY_INDEX", None);
        } else {
            os.environ["JAC_TOPOLOGY_INDEX"] = prev_env;
        }
        set_config(JacConfig());
    }
}

test "l3 fetch counter" {
    import from jaclang.runtimelib.memory { SqliteMemory }
    import from jaclang.jac0core.archetype { Root }
    tmpdir = mkdtemp();
    try {
        mem = SqliteMemory(path=os.path.join(tmpdir, "test.db"));
        assert mem.l3_fetch_count == 0;
        r = Root();
        anchor = r.__jac__;
        anchor.persistent = True;
        mem.put(anchor);
        mem.sync();
        mem.__mem__.clear();
        mem.get(anchor.id);  # Cache miss, hits DB
        assert mem.l3_fetch_count == 1;
        # Cache hit — no increment
        mem.get(anchor.id);
        assert mem.l3_fetch_count == 1;
    } finally {
        mem.close();
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "topology index survives anchor serialization" {
    import pickle;
    import from jaclang.jac0core.archetype { Root, NodeAnchor }
    r = Root();
    anchor = r.__jac__;
    idx = TopologyIndex();
    n1 = uuid4();
    idx.add_node(anchor.id, "Root");
    idx.add_node(n1, "NodeA");
    idx.add_edge(anchor.id, n1, "EdgeX");
    anchor.set_topology_index(idx);

    state = anchor.__getstate__();
    assert "topology_index_data" in state;

    restored = object.__new__(NodeAnchor);
    restored.__setstate__(state);
    decoded = restored.get_topology_index();
    assert len(decoded.adj_list) == 1;
    assert len(decoded.node_table) == 2;
}

test "concurrent edge adds merged in sqlite sync" {
    import from jaclang.runtimelib.memory { SqliteMemory }
    import from jaclang.jac0core.archetype { Root, NodeAnchor, EdgeAnchor }
    tmpdir = mkdtemp();
    try {
        db_path = os.path.join(tmpdir, "test.db");

        # Create root with one initial edge
        mem0 = SqliteMemory(path=db_path);
        r = Root();
        anchor = r.__jac__;
        anchor.persistent = True;
        e0: EdgeAnchor = EdgeAnchor.__new__(EdgeAnchor);
        e0.id = uuid4();
        e0.persistent = True;
        anchor.edges = [e0];
        mem0.put(anchor);
        mem0.close();  # close() must flush pending writes

        # Two "requests" load the same root
        mem_a = SqliteMemory(path=db_path);
        mem_b = SqliteMemory(path=db_path);
        got_a = mem_a.get(anchor.id);
        got_b = mem_b.get(anchor.id);
        assert got_a is not None and got_b is not None;
        assert isinstance(got_a, NodeAnchor) and isinstance(got_b, NodeAnchor);
        a: NodeAnchor = got_a;
        b: NodeAnchor = got_b;

        # A adds edge_a, B adds edge_b
        ea: EdgeAnchor = EdgeAnchor.__new__(EdgeAnchor);
        ea.id = uuid4();
        a.edges.append(ea);

        eb: EdgeAnchor = EdgeAnchor.__new__(EdgeAnchor);
        eb.id = uuid4();
        b.edges.append(eb);

        # Commit A then B — B must not overwrite A's edge
        mem_a.sync();
        mem_b.sync();
        mem_a.close();
        mem_b.close();

        # Verify all 3 edges exist
        mem_c = SqliteMemory(path=db_path);
        got_c = mem_c.get(anchor.id);
        assert got_c is not None and isinstance(got_c, NodeAnchor);
        result: NodeAnchor = got_c;
        ids = set(e.id for e in result.edges);
        assert e0.id in ids , "Initial edge lost";
        assert ea.id in ids , "Edge A lost — overwritten by B";
        assert eb.id in ids , "Edge B lost";
        assert len(ids) == 3 , f"Expected 3, got {len(ids)}";
        mem_c.close();
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

"""Slicing on edge-ref `[-->][?:T][a:b]` must push the bound down to the storage
layer — only the sliced subset should hit SQLite, not every neighbor."""
test "edge-ref slice bounds sqlite l3 fetches" {
    tmpdir = mkdtemp();
    orig_base = JacRuntime.base_path_dir;
    try {
        cfg = JacConfig();
        cfg.run.topology_index = True;
        set_config(cfg);
        JacRuntime.set_base_path(tmpdir);

        # --- Phase 1: build graph (100 leads + 20 others), persist to SQLite ---
        ctx1 = ExecutionContext();
        JacRuntime.set_context(ctx1);

        for i in range(100) {
            root ++> _SliceLead(idx=i);
        }
        for i in range(20) {
            root ++> _SliceOther(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: fresh ctx (cold L1), run sliced query ---
        ctx2 = ExecutionContext();
        JacRuntime.set_context(ctx2);

        # Warm just the root so we measure traversal-only fetches.
        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        ctx2.mem.reset_l3_fetch_count();

        leads = [r2-->][?:_SliceLead][0:50];

        fetch_count = ctx2.mem.get_l3_fetch_count();
        assert len(leads) == 50 , f"Expected 50 leads, got {len(leads)}";
        # Production-grade pushdown: only the 50 sliced anchors should be loaded
        # (allow small overhead for any incidental fetches). Today this fails
        # because all 100 leads + ~120 edges are loaded.
        assert fetch_count <= 60 , (
            f"Slice should bound L3 fetches; got {fetch_count} fetches for [0:50]"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}
