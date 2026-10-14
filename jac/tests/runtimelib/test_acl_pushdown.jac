"""Permission is decided by the query, not by discarding rows afterwards.

`resolve_query` materialised every candidate and then dropped what the caller
could not see, so a gated read paid for rows it was never allowed to return --
and a bound could not be pushed at all, because `LIMIT` ahead of a filter still
running in Python changes `[:n]` from "n you may see" to "up to n, some of which
then vanish".

The standard model compiles: you own it (`root_id`), it is granted to everyone
(`access.all`), it is granted to you by name (`access.roots.anchors`), or the
root that owns it grants it to you or to everyone (a record owned by an org root
is reached through the one grant on that root). These are read in the order the
access check reads them, so an entry that names you with `NO_ACCESS` on the
record or on its owning root shuts out a broader grant. A
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


test "a grant on the owning root reaches its records through a typed hop" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        org_id: str;
        member_id: str;
        stranger_id: str;
        try {
            # An org root owns the records and a member holds one grant on the
            # org root, not an entry on every record.
            org = _mk_root(ctx.mem);
            member = _mk_root(ctx.mem);
            stranger = _mk_root(ctx.mem);
            _seed(ctx, org, org, 5, 0);
            JacRuntimeInterface.allow_root(org.archetype, member.id, AccessLevel.READ);
            ctx.mem.commit();
            org_id = str(org.id);
            member_id = str(member.id);
            stranger_id = str(stranger.id);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
        for (caller, want) in [(member_id, 5), (stranger_id, 0)] {
            ctx2 = _ctx(td);
            JacRuntime.exec_ctx = ctx2;
            try {
                ctx2.set_user_root(caller);
                hub = ctx2.mem.get(UUID(org_id));
                assert hub is not None;
                typed = len([_as_any(hub).archetype-->[?:Doc]]);
                untyped = len([_as_any(hub).archetype-->]);
                assert typed == want , (
                    f"a typed hop returned {typed} of the {want} records the "
                    "owning root's grant admits"
                );
                assert untyped == want , (
                    f"the untyped hop returned {untyped}, expected {want}"
                );
            } finally {
                JacRuntime.exec_ctx = old;
                ctx2.close();
            }
        }
    }
}


"""Owner `org` holds one Doc; set `member`'s grants on the org root, the Doc, and a team the member belongs to."""
def _seed_grants(
    ctx: ExecutionContext,
    org: any,
    member: any,
    grants: tuple[int, (int | None), int, (int | None), (int | None)]
) {
    (org_all, org_member, doc_all, doc_member, doc_team) = grants;
    mk = str(member.id);
    d = Doc(label="d").__jac__;
    d.persistent = True;
    setattr(d, "root", org.id);
    ctx.mem.put(d);
    e = EdgeAnchor(archetype=GenericEdge(), source=org, target=d, is_undirected=False);
    e.persistent = True;
    org.edges.append(e);
    d.edges.append(e);
    ctx.mem.put(e);
    if org_all > -1 {
        org.own_access().all = AccessLevel(org_all);
    }
    if org_member is not None {
        org.own_access().roots.anchors[mk] = AccessLevel(org_member);
    }
    if doc_all > -1 {
        d.own_access().all = AccessLevel(doc_all);
    }
    if doc_member is not None {
        d.own_access().roots.anchors[mk] = AccessLevel(doc_member);
    }
    if doc_team is not None {
        team = Team(name="t").__jac__;
        team.persistent = True;
        setattr(team, "root", org.id);
        ctx.mem.put(team);
        m = EdgeAnchor(
            archetype=MemberOf(), source=member, target=team, is_undirected=False
        );
        m.persistent = True;
        member.edges.append(m);
        team.edges.append(m);
        ctx.mem.put(m);
        d.own_access().groups.anchors[str(team.id)] = AccessLevel(doc_team);
    }
    ctx.mem.put(org);
    ctx.mem.put(d);
}


test "a typed hop gives the access check's answer for every grant and override" {
    # (label, org all, org entry for member, doc all, doc entry for member,
    #  doc grant to member's team, visible)
    rows = [
        ("no grant", -1, None, -1, None, None, 0),
        ("grant on the org root", -1, 0, -1, None, None, 1),
        ("grant on the doc", -1, None, -1, 0, None, 1),
        ("doc granted to all", -1, None, 0, None, None, 1),
        ("org root granted to all", 0, None, -1, None, None, 1),
        ("org root grant, doc blocks the member", -1, 0, -1, -1, None, 0),
        ("doc granted to all, doc blocks the member", -1, None, 0, -1, None, 0),
        ("doc granted to all, org root blocks the member", -1, -1, 0, None, None, 0),
        (
            "org root granted to all, org root blocks the member",
            0,
            -1,
            -1,
            None,
            None,
            0
        ),
        ("doc blocks the member and grants nothing else", -1, None, -1, -1, None, 0),
        ("team grant", -1, None, -1, None, 0, 1),
        ("team entry at NO_ACCESS", -1, None, -1, None, -1, 0),
        ("org root grant, team entry at NO_ACCESS", -1, 0, -1, None, -1, 1),
        ("doc blocks the member, team grant lifts it", -1, None, -1, -1, 0, 1),

    ];
    for (label, org_all, org_member, doc_all, doc_member, doc_team, want) in rows {
        with TemporaryDirectory() as td {
            old = JacRuntime.exec_ctx;
            ctx = _ctx(td);
            JacRuntime.exec_ctx = ctx;
            org_id: str;
            member_id: str;
            try {
                org = _mk_root(ctx.mem);
                member = _mk_root(ctx.mem);
                _seed_grants(
                    ctx,
                    org,
                    member,
                    (org_all, org_member, doc_all, doc_member, doc_team)
                );
                ctx.mem.commit();
                org_id = str(org.id);
                member_id = str(member.id);
            } finally {
                JacRuntime.exec_ctx = old;
                ctx.close();
            }
            ctx2 = _ctx(td);
            JacRuntime.exec_ctx = ctx2;
            try {
                ctx2.set_user_root(member_id);
                hub = ctx2.mem.get(UUID(org_id));
                assert hub is not None;
                untyped = len([_as_any(hub).archetype-->]);
                typed = len([_as_any(hub).archetype-->[?:Doc]]);
                assert untyped == want , f"{label}: the access check admitted {untyped}";
                assert typed == want , (
                    f"{label}: a typed hop returned {typed}, the access check {want}"
                );
            } finally {
                JacRuntime.exec_ctx = old;
                ctx2.close();
            }
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
