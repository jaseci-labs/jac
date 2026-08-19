"""Multi-hop chain expressions compile to ONE SQL statement.

The per-anchor call-count of loop-style app code (one traversal per
frontier node) is the dominant DB cost on read paths; the escape hatch is
that a chain written as one expression fuses into a single join. Measured
on the littleX feed: the loop form issues 309 statements per request, the
chain form 10, byte-identical results. These tests pin the fusion so it
cannot silently regress, in both the legacy and relational compile modes.
"""

import from jaclang.jac0core.graph_query { GraphQuery, QHop }
import from jaclang.runtimelib.sqlcompile { chain_relational_ok, compile_query }

node CFProfile {
    has name: str = "";
}

node CFTweet {
    has content: str = "";
}

edge CFFollow {}


def _two_hop_query -> GraphQuery {
    origin = CFProfile(name="o");
    return GraphQuery(
        origin,
        hops=[QHop(dir=2, `edge=CFFollow, nd=CFProfile), QHop(dir=2, nd=CFTweet)]
    );
}


test "a two-hop chain compiles to a single legacy statement" {
    cq = compile_query(_two_hop_query(), 2);
    assert cq.sql.count('SELECT') == 1 + cq.sql.count('(SELECT') , (
        "one statement, no accidental statement splitting"
    );
    assert 'JOIN anchors e1' in cq.sql and 'JOIN anchors e2' in cq.sql , (
        f"both hops must join in the same statement: {cq.sql}"
    );
    assert not cq.residual , "type-only chain has nothing residual";
}

test "a two-hop chain compiles to a single relational statement" {
    q = _two_hop_query();
    assert chain_relational_ok(q, 2) , "type-only chain is relational-eligible";
    cq = compile_query(q, 2, relational=True);
    assert 'JOIN edges e1' in cq.sql and 'JOIN edges e2' in cq.sql;
    assert 'JOIN nodes n1' in cq.sql and 'JOIN nodes n2' in cq.sql;
    # pre-cutover truth guards: every emitted row must exist in anchors
    assert 'JOIN anchors ea1' in cq.sql and 'JOIN anchors an2' in cq.sql;
}

test "predicate hops are not relational-eligible" {
    import from jaclang.jac0core.graph_query { QPred }
    origin = CFProfile(name="o");
    q = GraphQuery(
        origin,
        hops=[
            QHop(dir=2, nd=CFTweet, preds=[QPred(field='content', op='==', value='x')])
        ]
    );
    assert not chain_relational_ok(q, 1) , (
        "residuals are not re-applied to SQL rows; pred chains stay legacy"
    );
}
