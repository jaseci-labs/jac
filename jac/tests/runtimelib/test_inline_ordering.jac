"""Ordering written where the filter is written.

Predicates already live in two places that encode which side they read: the
hop slot (`->:Posted:sent > 3:->`) names the edge, the filter bracket
(`[?:Msg, at > 3]`) names the node. Ordering now uses the same two positions
and the same comma list, so the side is encoded by where the term sits rather
than by an annotation:

    [chan ->:Posted:-sent:-> [?:Msg]]        order by the carrying edge, desc
    [chan ->:Posted:-> [?:Msg, -at]]         order by the node's field, desc
    [chan ->:Posted:-> [?:Msg, at > 3, -at]] filter and order together

An ordering term is a bare field name (ascending) or its negation
(descending); a predicate always carries a comparison operator, so the two are
distinguishable by shape and never ambiguous. This is the only way a traversal
can order on an edge field, since the result list holds nodes.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

node IBoard {
    has name: str = "";
}

node IItem {
    has rank: int = 0,
        mark: int = 0;
}

edge ISent: IBoard --> IItem {
    has sent: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "io_app.jac")
    );
}


"""ranks 3,1,4,1,5 attached with descending `sent` so the two orders differ."""
def _seed -> IBoard {
    b = IBoard(name="b");
    root ++> b;
    ranks = [3, 1, 4, 1, 5];
    for (i, r) in enumerate(ranks) {
        b +>:ISent(sent=100 - i):+> IItem(rank=r, mark=i);
    }
    return b;
}


test "a node-field ordering term sorts the result" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            asc = [b->:ISent:->[?:IItem, rank]];
            assert [_as_any(x).rank for x in asc] == [1, 1, 3, 4, 5] , (
                [_as_any(x).rank for x in asc]
            );
            desc = [b->:ISent:->[?:IItem, -rank]];
            assert [_as_any(x).rank for x in desc] == [5, 4, 3, 1, 1] , (
                [_as_any(x).rank for x in desc]
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "an edge-field ordering term sorts by the carrying edge" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            by_edge = [b->:ISent:sent:->[?:IItem]];
            assert [_as_any(x).mark for x in by_edge] == [4, 3, 2, 1, 0] , (
                f"ascending edge `sent` should reverse insertion order; got "
                f"{[_as_any(x).mark for x in by_edge]}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a predicate and an ordering term coexist in one list" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            got = [b->:ISent:->[?:IItem, rank>1, -rank]];
            assert [_as_any(x).rank for x in got] == [5, 4, 3] , (
                [_as_any(x).rank for x in got]
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "an inline ordering composes with a bound and reads only the bound" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            b2 = [root-->[?:IBoard]][0];
            ctx2.mem.reset_fetch_count();
            top = [b2->:ISent:->[?:IItem, -rank]][:2];
            fetched = ctx2.mem.get_fetch_count();
            assert [_as_any(x).rank for x in top] == [5, 4] , (
                [_as_any(x).rank for x in top]
            );
            assert fetched <= 2 , (
                f"a bounded inline ordering read {fetched} anchors out of 5"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
