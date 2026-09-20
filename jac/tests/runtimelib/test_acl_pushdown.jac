"""Permission is decided by the query, not by discarding rows afterwards.

`resolve_query` materialised every candidate and then dropped what the caller
could not see, so a gated read paid for rows it was never allowed to return --
and a bound could not be pushed at all, because `LIMIT` ahead of a filter still
running in Python changes `[:n]` from "n you may see" to "up to n, some of which
then vanish".

The standard model compiles: you own it (`root_id`), it is granted to everyone
(`access.all`), or it is granted to you by name (`access.roots.anchors`). A
per-root grant does not scale to a large audience, so a grant may also name a
*group*, and membership is an edge -- one grant, one membership per member,
instead of one dict entry per member on every object.

An archetype that overrides `__jac_access__` runs arbitrary Jac, which has no
SQL form, so those must decline any pushdown and keep the object-space filter.
The decline is the point: correctness never depends on whether a query could be
compiled.

"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.archetype { AccessLevel, EdgeAnchor, GenericEdge, Root }
import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface }
import from jaclang.runtime.context { ExecutionContext }

node Doc {
    has label: str = "";
}

node Team {
    has name: str = "";
}

edge MemberOf: any --> any {}

node CustomDoc {
    has label: str = "";

    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "acl_app.jac")
    );
}


def _mk_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    mem.put(anch);
    return anch;
}


"""Attach `n` Docs owned by `owner` under `hub`, granting `granted` of them to all."""
def _seed(ctx: ExecutionContext, hub: any, owner: any, n: int, granted: int) {
    for i in range(n) {
        d = Doc(label=f"d{i}").__jac__;
        d.persistent = True;
        setattr(d, "root", owner.id);
        if i < granted {
            d.own_access().all = AccessLevel.READ;
        }
        ctx.mem.put(d);
        e = EdgeAnchor(
            archetype=GenericEdge(), source=hub, target=d, is_undirected=False
        );
        e.persistent = True;
        hub.edges.append(e);
        d.edges.append(e);
        ctx.mem.put(e);
    }
}


test "a gated read does not materialize rows it may not return" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        hub_id: str;
        try {
            owner = _mk_root(ctx1.mem);
            other = _mk_root(ctx1.mem);
            _seed(ctx1, other, owner, 30, 3);
            ctx1.mem.commit();
            hub_id = str(other.id);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        # A cold context: nothing is in __mem__, so every row the read touches
        # is a real store fetch and the counter means something.
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ctx2.set_user_root(hub_id);
            hub = ctx2.mem.get(UUID(hub_id));
            assert hub is not None;
            ctx2.mem.reset_fetch_count();
            visible = len([x for x in [_as_any(hub).archetype-->[?:Doc]]]);
            fetched = ctx2.mem.get_fetch_count();
            assert visible == 3 , f"expected the 3 granted docs, got {visible}";
            assert fetched <= 3 , (
                f"a gated read materialized {fetched} anchors to return 3; the "
                f"permission test belongs in the query"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a bound is pushed even when the request is gated" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        hub_id: str;
        try {
            owner = _mk_root(ctx.mem);
            other = _mk_root(ctx.mem);
            _seed(ctx, other, owner, 30, 20);
            ctx.mem.commit();
            hub_id = str(other.id);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ctx2.set_user_root(hub_id);
            hub = ctx2.mem.get(UUID(hub_id));
            assert hub is not None;
            ctx2.mem.reset_fetch_count();
            head = [_as_any(hub).archetype-->[?:Doc]][:4];
            fetched = ctx2.mem.get_fetch_count();
            assert len(head) == 4 , len(head);
            assert fetched <= 4 , (
                f"a bounded gated read materialized {fetched} anchors for 4 rows"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "a grant to a group reaches every member without a per-root entry" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            reader = _mk_root(ctx.mem);

            team = Team(name="eng").__jac__;
            team.persistent = True;
            setattr(team, "root", owner.id);
            ctx.mem.put(team);

            # membership is an edge, not an entry on every granted object
            m = EdgeAnchor(
                archetype=MemberOf(), source=reader, target=team, is_undirected=False
            );
            m.persistent = True;
            reader.edges.append(m);
            team.edges.append(m);
            ctx.mem.put(m);

            d = Doc(label="team-doc").__jac__;
            d.persistent = True;
            setattr(d, "root", owner.id);
            ctx.mem.put(d);
            e = EdgeAnchor(
                archetype=GenericEdge(), source=reader, target=d, is_undirected=False
            );
            e.persistent = True;
            reader.edges.append(e);
            d.edges.append(e);
            ctx.mem.put(e);

            JacRuntimeInterface.allow_group(d.archetype, team.id, AccessLevel.READ);
            ctx.mem.commit();

            ctx.set_user_root(str(reader.id));
            seen = [_as_any(x).label for x in [_as_any(reader.archetype)-->[?:Doc]]];
            assert seen == ["team-doc"] , (
                f"a group grant must reach a member; got {seen}"
            );
            assert d.access is None or not d.access.roots.anchors , (
                "a group grant must not write a per-root entry on the object"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a custom __jac_access__ declines the pushdown and still filters" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            other = _mk_root(ctx.mem);
            c = CustomDoc(label="custom").__jac__;
            c.persistent = True;
            setattr(c, "root", owner.id);
            ctx.mem.put(c);
            e = EdgeAnchor(
                archetype=GenericEdge(), source=other, target=c, is_undirected=False
            );
            e.persistent = True;
            other.edges.append(e);
            c.edges.append(e);
            ctx.mem.put(e);
            ctx.mem.commit();

            ctx.set_user_root(str(other.id));
            seen = [
                _as_any(x).label for x in [_as_any(other.archetype)-->[?:CustomDoc]]
            ];
            assert seen == ["custom"] , (
                f"__jac_access__ grants READ, so it must still be visible: {seen}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
