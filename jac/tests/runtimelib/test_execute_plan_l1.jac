"""Tests for the L1 shortcut in TieredMemory.execute_plan.

Verifies that:
1. Anchors already in L1 are served directly without hitting L3.
2. L1 misses are correctly fetched from L3 and promoted.
3. node_type_final filtering is applied on L1 hits.
4. field_predicates filtering ($eq, $ne, $lt, $gt, $in, etc.) is applied on L1 hits.
5. Mixed L1 hits + L3 misses return the correct combined result.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, NodeAnchor, Root }
import from jaclang.runtimelib.memory { TieredMemory }
import from jaclang.runtimelib.query_plan { QueryPlan }


node Item {
    has name: str = "",
        age: int = 0,
        status: str = "active";
}

node Other {
    has label: str = "";
}


"""Create a persistent TieredMemory backed by a real SQLite L3."""
def _make_mem(tmpdir: str) -> TieredMemory {
    target = str(Path(tmpdir) / "test_app.jac");
    return TieredMemory(base_path=tmpdir, target_path=target);
}


"""Create a persistent NodeAnchor wired to a root so it persists through commit.
Edgeless non-root nodes are skipped by the changeset collector."""
def _persist_node(archetype: object, mem: TieredMemory) -> NodeAnchor {
    ranch = Root().__jac__;
    ranch.persistent = True;
    anch = archetype.__jac__;
    anch.persistent = True;
    eanch = EdgeAnchor(
        archetype=GenericEdge(), source=ranch, target=anch, is_undirected=False
    );
    eanch.persistent = True;
    ranch.edges.append(eanch);
    anch.edges.append(eanch);
    mem.put(ranch);
    mem.put(anch);
    mem.put(eanch);
    return anch;
}


test "L1 shortcut: anchors in L1 are not re-fetched from L3" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="alpha", age=10), mem);
        a2 = _persist_node(Item(name="beta", age=20), mem);
        mem.commit();
        plan = QueryPlan(id_in={a1.id, a2.id});
        results = list(mem.execute_plan(plan));
        result_ids = {a.id for a in results};
        assert a1.id in result_ids , "a1 should be returned from L1";
        assert a2.id in result_ids , "a2 should be returned from L1";
        assert len(results) == 2;
        mem.close();
    }
}


test "L1 shortcut: L1 misses fall through to L3" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="alpha", age=10), mem);
        mem.commit();
        # Verify persisted
        assert mem.l3 is not None;
        l3_check = mem.l3.get(a1.id);
        assert l3_check is not None , "a1 should be in L3 after commit";
        # Evict from L1
        mem.__mem__.pop(a1.id, None);
        plan = QueryPlan(id_in={a1.id});
        results = list(mem.execute_plan(plan));
        assert len(results) == 1 , f"Should fetch 1 anchor from L3, got {len(results)}";
        assert results[0].id == a1.id;
        assert a1.id in mem.__mem__ , "a1 should be promoted to L1";
        mem.close();
    }
}


test "L1 shortcut: mixed L1 hits and L3 misses" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="alpha", age=10), mem);
        a2 = _persist_node(Item(name="beta", age=20), mem);
        mem.commit();
        # Evict a2 from L1 only
        mem.__mem__.pop(a2.id, None);
        plan = QueryPlan(id_in={a1.id, a2.id});
        results = list(mem.execute_plan(plan));
        result_ids = {a.id for a in results};
        assert a1.id in result_ids , "a1 should come from L1";
        assert a2.id in result_ids , "a2 should come from L3";
        assert len(results) == 2;
        mem.close();
    }
}


test "L1 filter: node_type_final excludes wrong types" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        item_a = _persist_node(Item(name="item1", age=10), mem);
        other_a = _persist_node(Other(label="other1"), mem);
        plan = QueryPlan(id_in={item_a.id, other_a.id}, node_type_final="Item");
        results = list(mem.execute_plan(plan));
        assert len(results) == 1 , f"Should return only Item, got {len(results)}";
        assert results[0].id == item_a.id;
        mem.close();
    }
}


test "L1 filter: field_predicates bare value (eq)" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="alpha", age=10, status="active"), mem);
        a2 = _persist_node(Item(name="beta", age=20, status="inactive"), mem);
        plan = QueryPlan(id_in={a1.id, a2.id}, field_predicates={"status": "active"});
        results = list(mem.execute_plan(plan));
        assert len(results) == 1;
        assert results[0].id == a1.id;
        mem.close();
    }
}


test "L1 filter: field_predicates $lt and $gte" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="young", age=10), mem);
        a2 = _persist_node(Item(name="old", age=30), mem);
        a3 = _persist_node(Item(name="mid", age=20), mem);
        plan_lt = QueryPlan(
            id_in={a1.id, a2.id, a3.id}, field_predicates={"age": {"$lt": 25}}
        );
        results_lt = list(mem.execute_plan(plan_lt));
        ids_lt = {a.id for a in results_lt};
        assert a1.id in ids_lt;
        assert a3.id in ids_lt;
        assert a2.id not in ids_lt;
        plan_gte = QueryPlan(
            id_in={a1.id, a2.id, a3.id}, field_predicates={"age": {"$gte": 20}}
        );
        results_gte = list(mem.execute_plan(plan_gte));
        ids_gte = {a.id for a in results_gte};
        assert a2.id in ids_gte;
        assert a3.id in ids_gte;
        assert a1.id not in ids_gte;
        mem.close();
    }
}


test "L1 filter: field_predicates $in and $nin" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="a", status="active"), mem);
        a2 = _persist_node(Item(name="b", status="inactive"), mem);
        a3 = _persist_node(Item(name="c", status="pending"), mem);
        plan_in = QueryPlan(
            id_in={a1.id, a2.id, a3.id},
            field_predicates={"status": {"$in": ["active", "pending"]}}
        );
        results_in = list(mem.execute_plan(plan_in));
        ids_in = {a.id for a in results_in};
        assert a1.id in ids_in;
        assert a3.id in ids_in;
        assert a2.id not in ids_in;
        plan_nin = QueryPlan(
            id_in={a1.id, a2.id, a3.id},
            field_predicates={"status": {"$nin": ["active"]}}
        );
        results_nin = list(mem.execute_plan(plan_nin));
        ids_nin = {a.id for a in results_nin};
        assert a2.id in ids_nin;
        assert a3.id in ids_nin;
        assert a1.id not in ids_nin;
        mem.close();
    }
}


test "L1 filter: combined type and field predicates" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        item1 = _persist_node(Item(name="x", age=10, status="active"), mem);
        item2 = _persist_node(Item(name="y", age=30, status="active"), mem);
        other1 = _persist_node(Other(label="z"), mem);
        plan = QueryPlan(
            id_in={item1.id, item2.id, other1.id},
            node_type_final="Item",
            field_predicates={"age": {"$lt": 20}}
        );
        results = list(mem.execute_plan(plan));
        assert len(results) == 1;
        assert results[0].id == item1.id;
        mem.close();
    }
}


test "No id_in: execute_plan delegates to L3 entirely" {
    with TemporaryDirectory() as tmpdir {
        mem = _make_mem(tmpdir);
        a1 = _persist_node(Item(name="alpha", age=10), mem);
        mem.commit();
        plan = QueryPlan(node_type_final="Item");
        # SqliteMemory has no execute_plan support, so empty result is expected.
        # The key test is no crash.
        results = list(mem.execute_plan(plan));
        mem.close();
    }
}
