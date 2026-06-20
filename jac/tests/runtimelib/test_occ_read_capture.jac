"""Read-set optimistic-concurrency *integration* tests (#6266 follow-up).

These drive the read-capture half of OCC through the real
walker -> `refs` -> planner path. The backend-level tests (`test_occ_sqlite`)
deliberately set `WriteIntent.cas_version` by hand, so they validate the
version-CAS primitive but not the runtime wiring that decides *when* it fires.

Two defects motivated these:

  1. Read capture lived only in the `edges_to_nodes` slow path. Once a root
     carries any child its topology index is populated, so `refs` resolves
     `[-->(?:T)]` via the planner fast path (`execute_path`) and returns
     without ever calling `edges_to_nodes` -- no read version recorded, the
     CAS never fires, and concurrent find-or-create still duplicates. Edge
     references (`[edge -->]`) recorded nothing either.

  2. `read_versions` was never refreshed after a commit, so a request that
     read a persisted node and then committed two edge changes to it
     conflicted with its *own* first commit (exhausted replay -> 409 on the
     server, or an uncaught WriteConflict in CLI/library flows).

Anchor handles are typed `any`: the checker has no stub for `.__jac__`.
"""

import shutil;
import from tempfile { mkdtemp }

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jaclang.project.config { JacConfig, set_config }


node Profile {
    has uid: str = "";
}

node Tag {
    has name: str = "";
}

edge Owns {}


"""Persistent ExecutionContext with the topology index on (the default), so
`refs` takes the planner fast path once the root has a child."""
def _persistent_ctx(tmpdir: str) -> any {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path(tmpdir);
    ctx: any = ExecutionContext();
    JacRuntime.set_context(ctx);
    return ctx;
}


"""Attach one child and flush, so the root is persisted (edge writes then
merge + CAS) and its topology index is populated."""
walker Seed {
    can go with entry {
        here ++> Tag(name="seed");
        commit();
    }
}


"""find-or-create check of an absent type -> planner fast path on a populated
root. Asserts inside the walk so the read-set is observed on the live ctx."""
walker ReadProfiles {
    can go with entry {
        existing = [-->(?:Profile)];
        rv = JacRuntime.get_context().read_versions;
        assert here.__jac__.id in rv , "planner fast path must record the origin version for OCC";
    }
}


"""Edge-only read (`get_edges` path, never `edges_to_nodes`) must record the
dependency too -- find-or-create keyed on edge existence was unprotected."""
walker ReadEdges {
    can go with entry {
        owned = [edge -->];
        rv = JacRuntime.get_context().read_versions;
        assert here.__jac__.id in rv , "edge-only read must record the origin version for OCC";
    }
}


"""Read a persisted node, then commit two edge changes to it. The second
commit must not conflict with this request's own first commit."""
walker TwiceCommit {
    has conflicted: bool = False;

    can go with entry {
        existing = [-->];
        here ++> Tag(name="a");
        commit();
        here ++> Tag(name="b");
        try {
            commit();
        } except WriteConflict {
            self.conflicted = True;
        }
    }
}


test "OCC read capture: planner fast path records the read dependency" {
    tmpdir = mkdtemp();
    orig = JacRuntime.get_base_path_dir();
    try {
        ctx: any = _persistent_ctx(tmpdir);
        root spawn Seed();
        assert len(root.__jac__.get_topology_index()) > 0;
        ctx.read_versions.clear();
        root spawn ReadProfiles();
        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


test "OCC read capture: edge-only read records the read dependency" {
    tmpdir = mkdtemp();
    orig = JacRuntime.get_base_path_dir();
    try {
        ctx: any = _persistent_ctx(tmpdir);
        root spawn Seed();
        ctx.read_versions.clear();
        root spawn ReadEdges();
        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


test "OCC read capture: a second commit does not self-conflict" {
    tmpdir = mkdtemp();
    orig = JacRuntime.get_base_path_dir();
    try {
        ctx: any = _persistent_ctx(tmpdir);
        root spawn Seed();
        ctx.read_versions.clear();
        w: any = TwiceCommit();
        root spawn w;
        assert not w.conflicted , "a request must not conflict with its own prior commit";
        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig);
        set_config(JacConfig());
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}
