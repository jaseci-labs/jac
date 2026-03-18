"""Integration tests for topology index — config, instrumentation, serialization."""

import os;
import shutil;
import from tempfile { mkdtemp }
import from uuid { uuid4 }
import from jaclang.runtimelib.topology_index { TopologyIndex }

test "topology index config from toml" {
    import from jaclang.project.config { JacConfig }
    toml_str = "[project]\nname = \"test\"\n\n[run]\ntopology_index = false\n";
    cfg = JacConfig.from_toml_str(toml_str);
    assert cfg.run.topology_index is False;
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
        mem.__mem__.clear();
        mem.get(anchor.id);
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
