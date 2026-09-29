"""`sorted(<traversal>, key=...)` folds into the query's ORDER BY.

Ordering by a node field meant materialising the whole neighbourhood and
sorting it in Python. The keys real Jac actually writes are all one shape --
a field access, optionally negated, possibly in a tuple -- and that shape has
an exact ORDER BY equivalent, so the compiler pushes it.

A key annotated with anything other than the hop's node type does not fold and
falls through to ordinary checking, which is what an edge-typed key over a list
of nodes should get: `sorted`'s key must accept the list's element type, so
naming the edge side there is a genuine type error, not a case for the fold to
absorb. Ordering by an edge field is tracked separately in #8595. A key that is
a real computation cannot fold either, and keeps its object-space sort.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

node SBoard {
    has name: str = "";
}

node SItem {
    has rank: int = 0,
        boost: int = 0;
}

edge SAt: SBoard --> SItem {
    has at: int = 0;
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "sf_app.jac")
    );
}


def _seed -> SBoard {
    b = SBoard(name="b");
    root ++> b;
    ranks = [3, 1, 4, 1, 5, 9, 2, 6];
    for (i, r) in enumerate(ranks) {
        b +>:SAt(at=100 - i):+> SItem(rank=r, boost=i);
    }
    return b;
}


test "a node-field key orders in the query and needs no object-space sort" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            asc = sorted([b->:SAt:->[?:SItem]], key=lambda (s: SItem) { s.rank; });
            assert [_as_any(x).rank for x in asc] == [1, 1, 2, 3, 4, 5, 6, 9] , (
                [_as_any(x).rank for x in asc]
            );
            desc = sorted([b->:SAt:->[?:SItem]], key=lambda (s: SItem) { -s.rank; });
            assert [_as_any(x).rank for x in desc] == [9, 6, 5, 4, 3, 2, 1, 1] , (
                [_as_any(x).rank for x in desc]
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a folded ordering composes with a bound and reads only the bound" {
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
            b2 = [root-->[?:SBoard]][0];
            ctx2.mem.reset_fetch_count();
            top = sorted([b2->:SAt:->[?:SItem]], key=lambda (s: SItem) { -s.rank; })[:3];
            fetched = ctx2.mem.get_fetch_count();
            assert [_as_any(x).rank for x in top] == [9, 6, 5] , (
                [_as_any(x).rank for x in top]
            );
            assert fetched <= 3 , (
                f"a folded top-3 read {fetched} anchors out of 8; the ordering "
                f"and the bound must land in the same query"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a tuple key orders by every term in order" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            got = sorted(
                [b->:SAt:->[?:SItem]], key=lambda (s: SItem) { (s.rank, -s.boost); }
            );
            pairs = [(_as_any(x).rank, _as_any(x).boost) for x in got];
            assert pairs
                == sorted(pairs, key=lambda (p: any) { (p[0], -p[1]); }) , pairs;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a computed key cannot fold and still sorts correctly" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            b = _seed();
            ctx.mem.commit();
            got = sorted(
                [b->:SAt:->[?:SItem]], key=lambda (s: SItem) { -(s.rank + s.boost); }
            );
            sums = [(_as_any(x).rank + _as_any(x).boost) for x in got];
            assert sums == sorted(sums, reverse=True) , sums;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
