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
SQL form. Its rows (and roots, whose access has rules of their own) pass the
query as candidates and are decided in object space, and a bounded read keeps
reading until the bound is filled. Correctness never depends on whether a query
could be compiled.

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

edge Tagged: any --> any {
    has label: str = "";
}

edge CustomLink: any --> any {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

node CustomHidden {
    has label: str = "";

    def __jac_access__ -> AccessLevel {
        return AccessLevel.NO_ACCESS;
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
        ("org root blocks the member, doc grants the member", -1, -1, -1, 0, None, 1),

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


test "a custom __jac_access__ decides visibility on every read path" {
    import from jaclang.data.query_planner {
        COUNT_CHECK_CAP,
        PAGE_SCAN_FLOOR,
        resolve_query,
        resolve_query_edges,
        resolve_query_page,
        resolve_query_type_counts
    }
    import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            other = _mk_root(ctx.mem);
            # In edge order: two nodes granted to all whose hook denies, four
            # plain grants, one hook grant, a granted node behind an edge the
            # reader may not read, and one more hook denial. A page has to look
            # past the first two to fill itself, and knows nothing readable
            # follows its last row.
            made = [
                CustomHidden(label="h0"),
                CustomHidden(label="h1"),
                Doc(label="d0"),
                Doc(label="d1"),
                Doc(label="d2"),
                Doc(label="d3"),
                CustomDoc(label="custom"),
                Doc(label="private-edge"),
                CustomHidden(label="h2")
            ];
            for arch in made {
                c = arch.__jac__;
                c.persistent = True;
                setattr(c, "root", owner.id);
                if not isinstance(arch, CustomDoc) {
                    c.own_access().all = AccessLevel.READ;
                }
                ctx.mem.put(c);
                e = EdgeAnchor(
                    archetype=GenericEdge(), source=other, target=c, is_undirected=False
                );
                e.persistent = True;
                private = _as_any(arch).label == "private-edge";
                setattr(e, "root", owner.id if private else other.id);
                other.edges.append(e);
                c.edges.append(e);
                ctx.mem.put(e);
            }
            # The hook-granted node reaches d1 twice, once through an edge
            # whose own hook grants it: still one node.
            for kind in [GenericEdge, CustomLink] {
                link = EdgeAnchor(
                    archetype=kind(),
                    source=made[6].__jac__,
                    target=made[3].__jac__,
                    is_undirected=False
                );
                link.persistent = True;
                setattr(link, "root", owner.id);
                made[6].__jac__.edges.append(link);
                made[3].__jac__.edges.append(link);
                ctx.mem.put(link);
            }
            # Behind a hook-denied node and behind a readable one: only the
            # second is reachable in two hops.
            for (label, via) in [("behind-hidden", made[0]), ("behind-d0", made[2])] {
                b = Doc(label=label).__jac__;
                b.persistent = True;
                setattr(b, "root", owner.id);
                b.own_access().all = AccessLevel.READ;
                ctx.mem.put(b);
                e = EdgeAnchor(
                    archetype=GenericEdge(),
                    source=via.__jac__,
                    target=b,
                    is_undirected=False
                );
                e.persistent = True;
                setattr(e, "root", owner.id);
                via.__jac__.edges.append(e);
                b.edges.append(e);
                ctx.mem.put(e);
            }

            def attach(
                src: any, label: str, kind: type, edge_owner: any, via: any = None
            ) -> any {
                x = kind(label=label).__jac__;
                x.persistent = True;
                setattr(x, "root", owner.id);
                if kind is Doc {
                    x.own_access().all = AccessLevel.READ;
                }
                ctx.mem.put(x);
                link = EdgeAnchor(
                    archetype=via if via is not None else GenericEdge(),
                    source=src.__jac__,
                    target=x,
                    is_undirected=False
                );
                link.persistent = True;
                setattr(link, "root", edge_owner.id);
                src.__jac__.edges.append(link);
                x.edges.append(link);
                ctx.mem.put(link);
                return x;
            }
            # d2 reaches a granted doc through an edge only its owner may read,
            # then an open one: a bounded edge read must look past the first.
            attach(made[4], "x-private", Doc, owner);
            attach(made[4], "x-open", Doc, other);
            # d3 reaches a node whose stored type this process does not know
            # (renamed below); only its hook grants it.
            renamed = attach(made[5], "renamed-hook", CustomDoc, other);
            # A node with more hook-decided neighbors than a count will check.
            crowd = attach(owner.archetype, "crowd", Doc, owner);
            for i in range(COUNT_CHECK_CAP + 1) {
                attach(crowd.archetype, f"c{i}", CustomDoc, other);
            }
            # Two tagged edges whose tag only Python can match; the node at the
            # end of the kept one has no tag of its own.
            tags = attach(owner.archetype, "tags", Doc, owner);
            attach(tags.archetype, "t-drop", Doc, other, Tagged(label="drop"));
            attach(tags.archetype, "t-keep", Doc, other, Tagged(label="keep"));
            # A neighbor this process cannot materialize (as with a class that
            # lives in another service), so it cannot check it.
            unloaded = attach(owner.archetype, "unloaded", Doc, owner);
            lost = attach(unloaded.archetype, "lost", CustomDoc, other);
            # More hook-denied neighbors than one page may examine.
            walled = attach(owner.archetype, "walled", Doc, owner);
            for i in range(PAGE_SCAN_FLOOR + 50) {
                attach(walled.archetype, f"w{i}", CustomHidden, other);
            }
            ctx.mem.commit();
            store: any = ctx.mem.store;
            store.rows(
                "UPDATE anchors SET arch_type = 'gone.CustomDoc' WHERE id = CAST(:i AS uuid)",
                {"i": str(renamed.id)}
            );
            store.rows(
                "UPDATE anchors SET props = props - '__type__' WHERE id = CAST(:i AS uuid)",
                {"i": str(lost.id)}
            );
            _as_any(ctx.mem).__mem__.pop(lost.id, None);

            ctx.set_user_root(str(other.id));
            hub = _as_any(other.archetype);
            visible = ["d0", "d1", "d2", "d3", "custom"];
            mem: any = ctx.mem;
            (page, cursor) = resolve_query_page(
                mem, GraphQuery(hub, hops=[QHop(dir=2)], limit=5)
            );
            (counts, _) = resolve_query_type_counts(
                mem, GraphQuery(hub, hops=[QHop(dir=2)])
            );
            (twice, _) = resolve_query_type_counts(
                mem, GraphQuery(made[6], hops=[QHop(dir=2)])
            );
            (unknown_page, _) = resolve_query_page(
                mem, GraphQuery(made[5], hops=[QHop(dir=2)], limit=5)
            );
            (unknown_counts, _) = resolve_query_type_counts(
                mem, GraphQuery(made[5], hops=[QHop(dir=2)])
            );
            (_, unloaded_exact) = resolve_query_type_counts(
                mem, GraphQuery(unloaded.archetype, hops=[QHop(dir=2)])
            );
            (crowd_counts, crowd_exact) = resolve_query_type_counts(
                mem, GraphQuery(crowd.archetype, hops=[QHop(dir=2)])
            );
            keep_tag = [QPred(field="label", op="in", value=frozenset({"keep"}))];
            tagged_edges = resolve_query_edges(
                mem,
                GraphQuery(
                    tags.archetype,
                    hops=[QHop(dir=2, epreds=keep_tag)],
                    edges_only=True,
                    limit=5
                )
            );
            tagged_nodes = resolve_query(
                mem, GraphQuery(tags.archetype, hops=[QHop(dir=2, epreds=keep_tag)])
            );
            tagged_page = resolve_query(
                mem,
                GraphQuery(tags.archetype, hops=[QHop(dir=2, epreds=keep_tag)], limit=5)
            );
            visited = resolve_query_edges(
                mem,
                GraphQuery(
                    hub, hops=[QHop(dir=2, nd=Doc)], edges_only=True, limit=1
                ).visit()
            );
            mem.reset_fetch_count();
            (walled_page, walled_next) = resolve_query_page(
                mem, GraphQuery(walled.archetype, hops=[QHop(dir=2)], limit=5)
            );
            walled_cost = mem.get_fetch_count();
            (walled_rest, walled_end) = resolve_query_page(
                mem,
                GraphQuery(
                    walled.archetype, hops=[QHop(dir=2)], limit=5, after=walled_next
                )
            );
            first_open = resolve_query_edges(
                mem,
                GraphQuery(
                    made[4], hops=[QHop(dir=2, nd=Doc)], edges_only=True, limit=1
                )
            );
            (whole, _) = resolve_query_page(
                mem, GraphQuery(hub, hops=[QHop(dir=2)], limit=20)
            );
            rows = [
                (
                    "untyped list",
                    [_as_any(x).label for x in [hub-->]],
                    visible + ["private-edge"]
                ),
                ("untyped count", len([hub-->]), 6),
                (
                    "two hops",
                    [_as_any(x).label for x in [hub-->-->]],
                    ["behind-d0", "x-private", "x-open", "renamed-hook", "d1"]
                ),
                ("two hop count", len([hub-->-->]), 5),
                (
                    "unknown stored type page",
                    [_as_any(a).archetype.label for (a, _, _) in unknown_page],
                    ["renamed-hook"]
                ),
                ("unknown stored type count", len([_as_any(made[5])-->]), 1),
                ("unknown stored type counts", sum(unknown_counts.values()), 1),
                (
                    "bounded edge read past an unreadable edge",
                    [_as_any(e).target.archetype.label for e in first_open],
                    ["x-open"]
                ),
                (
                    "edge tag on a bounded edge read",
                    [_as_any(e).archetype.label for e in tagged_edges],
                    ["keep"]
                ),
                (
                    "edge tag on a node read",
                    [_as_any(a).archetype.label for a in tagged_nodes],
                    ["t-keep"]
                ),
                (
                    "edge tag on a bounded node read",
                    [_as_any(a).archetype.label for a in tagged_page],
                    ["t-keep"]
                ),
                ("bounded visit keeps its bound", len(visited), 2),
                (
                    "a denied stretch ends the page early with a cursor",
                    (
                        len(walled_page),
                        walled_next is not None,
                        walled_cost <= PAGE_SCAN_FLOOR
                    ),
                    (0, True, True)
                ),
                (
                    "the cursor resumes after the examined rows",
                    (len(walled_rest), walled_end),
                    (0, None)
                ),
                (
                    "a neighbor nobody could check is not counted as exact",
                    unloaded_exact,
                    False
                ),
                (
                    "capped hook counts",
                    (sum(crowd_counts.values()), crowd_exact),
                    (COUNT_CHECK_CAP, False)
                ),
                ("page", [_as_any(a).archetype.label for (a, _, _) in page], visible),
                ("page ends", cursor, None),
                (
                    "whole page",
                    [_as_any(a).archetype.label for (a, _, _) in whole],
                    visible
                ),
                ("type counts", sum(counts.values()), 5),
                ("one node by two edges", sum(twice.values()), 1),
                ("untyped page", [_as_any(x).label for x in [hub-->][:5]], visible),
                (
                    "untyped offset page",
                    [_as_any(x).label for x in [hub-->][3:5]],
                    ["d3", "custom"]
                ),
                ("untyped exists", bool([hub-->]), True),
                (
                    "hook grant typed",
                    [_as_any(x).label for x in [hub-->[?:CustomDoc]]],
                    ["custom"]
                ),
                ("hook grant count", len([hub-->[?:CustomDoc]]), 1),
                ("hook deny typed count", len([hub-->[?:CustomHidden]]), 0),
                ("hook deny typed page", len([hub-->[?:CustomHidden]][:1]), 0)
            ];
            for (name, got, want) in rows {
                assert got == want , f"{name}: got {got}, want {want}";
            }
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
