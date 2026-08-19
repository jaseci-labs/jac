"""Relational shadow store (A2 of the relational schema program).

With JAC_RELATIONAL=shadow every flush dual-writes anchors AND the
relational layout (nodes directory, per-archetype typed tables, one edges
table) in the same transaction; anchors stays the source of truth and
relational_parity proves the copies agree. Every test runs against a real
embedded Postgres.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.relational { plan_for, relational_parity }

node RItem {
    has tag: str = "",
        num: int = 0,
        score: float = 0.0,
        flag: bool = False,
        blob: dict = {};
}

edge RRel {
    has w: int = 0;
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "rel_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


def _root(ctx: ExecutionContext) -> NodeAnchor {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    return ranch;
}


def _attach(
    ctx: ExecutionContext, ranch: NodeAnchor, tag: str, num: int
) -> NodeAnchor {
    nanch = RItem(tag=tag, num=num, score=1.5, flag=True, blob={'k': 1}).__jac__;
    nanch.persistent = True;
    eanch = EdgeAnchor(
        archetype=RRel(w=num), source=ranch, target=nanch, is_undirected=False
    );
    eanch.persistent = True;
    ranch.edges.append(eanch);
    nanch.edges.append(eanch);
    ctx.mem.put(nanch);
    ctx.mem.put(eanch);
    return nanch;
}


def _item_table(store: object) -> str {
    rows = store.rows(
        "SELECT table_name FROM graph_tables WHERE arch_type = 'RItem'", {}
    );
    assert rows , "RItem must be catalogued in graph_tables";
    return str(rows[0][0]);
}


test "shadow flush lands nodes in directory and typed table, edges in edges" {
    os.environ['JAC_RELATIONAL'] = 'shadow';
    try {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _make_ctx(td);
            JacRuntime.exec_ctx = ctx;
            try {
                ranch = _root(ctx);
                it = _attach(ctx, ranch, "x", 7);
                ctx.mem.commit();
                st = ctx.mem.store;

                dirr = st.rows(
                    'SELECT arch_type, root_id FROM nodes WHERE id = CAST(:id AS uuid)',
                    {'id': str(it.id)}
                );
                assert dirr and str(dirr[0][0]) == 'RItem' , (
                    f"directory row missing/wrong: {dirr}"
                );

                t = _item_table(st);
                tr = st.rows(
                    f"SELECT f_tag, f_num, f_score, f_flag FROM {t} "
                    'WHERE id = CAST(:id AS uuid)',
                    {'id': str(it.id)}
                );
                assert tr , f"typed row missing from {t}";
                assert str(tr[0][0]) == 'x';
                assert int(str(tr[0][1])) == 7;
                assert abs(float(str(tr[0][2])) - 1.5) < 1e-9;
                assert bool(tr[0][3]);

                er = st.rows("SELECT src, dst FROM edges WHERE edge_type = 'RRel'", {});
                assert er , 'RRel edge row missing';
                assert str(er[0][0]).replace('-', '') == ranch.id.hex;
                assert str(er[0][1]).replace('-', '') == it.id.hex;

                probs = relational_parity(st);
                assert probs == [] , f"parity: {probs}";
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    } finally {
        os.environ.pop('JAC_RELATIONAL', None);
    }
}


test "field update and delete propagate; parity stays clean" {
    os.environ['JAC_RELATIONAL'] = 'shadow';
    try {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _make_ctx(td);
            JacRuntime.exec_ctx = ctx;
            try {
                ranch = _root(ctx);
                it = _attach(ctx, ranch, "before", 1);
                ctx.mem.commit();
                st = ctx.mem.store;
                t = _item_table(st);

                it.archetype.tag = 'after';
                it.archetype.num = 42;
                ctx.mem.mark_dirty(it);
                ctx.mem.commit();
                tr = st.rows(
                    f"SELECT f_tag, f_num FROM {t} WHERE id = CAST(:id AS uuid)",
                    {'id': str(it.id)}
                );
                assert str(tr[0][0]) == 'after' and int(str(tr[0][1])) == 42 , (
                    f"update did not propagate: {tr}"
                );
                assert relational_parity(st) == [];

                for e in list(ranch.edges) {
                    ranch.edges.remove(e);
                    it.edges.remove(e);
                    ctx.mem.delete(e.id);
                }
                ctx.mem.delete(it.id);
                ctx.mem.commit();
                assert st.rows(
                    'SELECT id FROM nodes WHERE id = CAST(:id AS uuid)',
                    {'id': str(it.id)}
                )
                    == [];
                assert st.rows(
                    f"SELECT id FROM {t} WHERE id = CAST(:id AS uuid)",
                    {'id': str(it.id)}
                )
                    == [];
                assert st.rows("SELECT id FROM edges WHERE edge_type = 'RRel'", {})
                    == [];
                assert relational_parity(st) == [];
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
        }
    } finally {
        os.environ.pop('JAC_RELATIONAL', None);
    }
}


test "table plan derives typed columns for declared fields" {
    plan = plan_for('RItem', RItem.__module__);
    assert plan is not None , "plan must derive from manifest or reflection";
    tiers = {c.name: (c.tier, c.sql_type) for c in plan.columns};
    assert tiers['tag'] == ('scalar', 'text');
    assert tiers['num'] == ('scalar', 'bigint');
    assert tiers['score'] == ('scalar', 'double precision');
    assert tiers['flag'] == ('scalar', 'boolean');
    assert tiers['blob'][1] == 'jsonb';
}


test "disabled flag writes nothing relational" {
    os.environ.pop('JAC_RELATIONAL', None);
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            ranch = _root(ctx);
            _attach(ctx, ranch, "x", 1);
            ctx.mem.commit();
            st = ctx.mem.store;
            present = st.rows(
                """
                SELECT tablename FROM pg_tables
                WHERE schemaname = current_schema() AND tablename = 'nodes'
                """,
                {}
            );
            assert present == [] , "nodes table must not exist when disabled";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
