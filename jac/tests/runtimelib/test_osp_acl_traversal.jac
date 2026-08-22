"""ACL lives in the traversal seam (#7963 item 3).

Access filtering is a property of enumeration itself: `_hop_once` and the
`[edge -->]` arm apply `check_access_level` to everything they surface, so a
bare `[-->]`, a planner `GraphQuery`, and a walker's `visit [-->]` over the
same graph filter identically -- one transcript, three read paths. The gate
activates only for a downscoped user (`user_root` set and distinct from the
super root); single-tenant flows keep the lazy ungated hop path.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, Root }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.jac0core.graph_query { GraphQuery, QHop }
import from jaclang.runtimelib.query_planner { resolve_query }

node SecretNode {
    has label: str = "";
}

walker Probe {
    has seen: list[str] = [];

    can start with Root entry {
        visit [-->];
    }

    can see with SecretNode entry {
        self.seen.append(here.label);
        visit [-->];
    }
}

def _mk_user_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    anch.root = anch.id;
    mem.put(anch);
    return anch;
}

def _three_transcripts(origin_arch: any, mem: any) -> tuple {
    bare = [
        n.label
        for n in [origin_arch-->]
        if isinstance(n, SecretNode)
    ];
    planned = [
        a.archetype.label
        for a in resolve_query(
            mem, GraphQuery(origin_arch, hops=[QHop(dir=2, nd=SecretNode)])
        )
    ];
    w = Probe();
    w spawn origin_arch;
    return (bare, planned, w.seen);
}

test "bare refs, planner queries, and walker visits filter identically" {
    with TemporaryDirectory() as proj {
        target = str(Path(proj) / "acl_app.jac");
        orig_ctx = JacRuntime.exec_ctx;
        try {
            ctx = ExecutionContext(base_path_dir=proj, full_target_path=target);
            JacRuntime.exec_ctx = ctx;

            ra = _mk_user_root(ctx.mem);
            rb = _mk_user_root(ctx.mem);
            s = SecretNode(label="secret").__jac__;
            s.persistent = True;
            s.root = ra.id;
            ctx.mem.put(s);
            e = EdgeAnchor(
                archetype=GenericEdge(), source=rb, target=s, is_undirected=False
            );
            e.persistent = True;
            rb.edges.append(e);
            s.edges.append(e);
            ctx.mem.put(e);
            ctx.mem.commit();

            rb_arch = rb.archetype;

            ctx.set_user_root(str(rb.id));
            (bare_b, plan_b, walk_b) = _three_transcripts(rb_arch, ctx.mem);
            assert bare_b == [] , f"bare [-->] leaked A-private node to B: {bare_b}";
            assert plan_b == [] , f"planner query leaked A-private node to B: {plan_b}";
            assert walk_b == [] , f"walker visit leaked A-private node to B: {walk_b}";

            ctx.set_user_root(str(ra.id));
            (bare_a, plan_a, walk_a) = _three_transcripts(rb_arch, ctx.mem);
            assert bare_a == ["secret"] , f"owner bare [-->] transcript: {bare_a}";
            assert plan_a == ["secret"] , f"owner planner transcript: {plan_a}";
            assert walk_a == ["secret"] , f"owner walker transcript: {walk_a}";

            ctx.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
