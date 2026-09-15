"""Membership must not be a write over the group's content (issue #8460).

A per-root grant stores one entry per grantee inside each object's own
serialized props, so sharing with N members costs N entries on every object and
joining or leaving rewrites every content row. A group grant plus a membership
edge is the O(1) form: this asserts the invariant on real serialized rows -
every content row is byte-identical across both a join and a leave, while the
member's visibility flips.
"""

import from hashlib { sha256 }
import from json { dumps }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.archetype { AccessLevel, EdgeAnchor, GenericEdge, Root }
import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.data.serializer { Serializer }

node Item {
    has label: str = "";
}

node Team {
    has name: str = "";
}

edge MemberOf {}

def _as_any(v: any) -> any {
    return v;
}

def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "grp_app.jac")
    );
}

def _mk_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    mem.put(anch);
    return anch;
}

def _link(ctx: ExecutionContext, src: any, dst: any, kind: any) {
    e = EdgeAnchor(archetype=kind, source=src, target=dst, is_undirected=False);
    e.persistent = True;
    src.edges.append(e);
    dst.edges.append(e);
    ctx.mem.put(e);
}

"""Serialized fingerprint per content row, which is what a store write sees."""
def _fingerprints(ctx: ExecutionContext, ids: list[any]) -> dict[str, any] {
    out: dict[str, any] = {};
    for i in ids {
        anchor: any = ctx.mem.get(i);
        props = Serializer.serialize(anchor, include_type=True);
        out[str(i)] = sha256(
            dumps(props, `default=str, sort_keys=True).encode()
        ).hexdigest();
    }
    return out;
}

test "a group join and leave rewrite no content rows, and visibility flips" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            member = _mk_root(ctx.mem);
            team = Team(name="t").__jac__;
            team.persistent = True;
            setattr(team, "root", owner.id);
            ctx.mem.put(team);

            ids: list[any] = [];
            for i in range(8) {
                it = Item(label=f"i{i}").__jac__;
                it.persistent = True;
                setattr(it, "root", owner.id);
                ctx.mem.put(it);
                _link(ctx, owner, it, GenericEdge());
                JacRuntimeInterface.allow_group(
                    it.archetype, team.id, AccessLevel.READ
                );
                ids.append(it.id);
            }
            ctx.mem.commit();

            # Sharing is recorded once per object, keyed by the group.
            before = _fingerprints(ctx, ids);
            for i in ids {
                anchor: any = ctx.mem.get(i);
                assert not anchor.access.roots.anchors , (
                    "group sharing must not write a per-root entry"
                );
            }

            # Join: one edge. No content row may change.
            _link(ctx, member, team, MemberOf());
            ctx.mem.commit();
            joined = _fingerprints(ctx, ids);
            assert joined == before , (
                "joining rewrote content rows: "
                f"{[
                    k
                    for k in before
                    if before[k] != joined[k]
                ]}"
            );

            # The member can now read, so the join was real.
            ctx.set_user_root(str(member.id));
            seen = len(
                [
                    x
                    for x in [_as_any(_as_any(ctx.mem.get(owner.id)).archetype)-->[?:Item]]
                ]
            );
            assert seen == 8 , f"member saw {seen} of 8 items after joining";

            # Leave: drop the edge. Again no content row may change.
            ctx.set_user_root(str(owner.id));
            member_anchor: any = ctx.mem.get(member.id);
            for e in list(member_anchor.edges) {
                if isinstance(e.archetype, MemberOf) {
                    e.detach();
                    ctx.mem.delete(e.id);
                }
            }
            ctx.mem.commit();
            left = _fingerprints(ctx, ids);
            assert left == before , (
                "leaving rewrote content rows: "
                f"{[
                    k
                    for k in before
                    if before[k] != left[k]
                ]}"
            );

            ctx.set_user_root(str(member.id));
            seen_after = len(
                [
                    x
                    for x in [_as_any(_as_any(ctx.mem.get(owner.id)).archetype)-->[?:Item]]
                ]
            );
            assert seen_after == 0 , (
                f"member still saw {seen_after} items after leaving"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
