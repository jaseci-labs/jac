"""Tests for ExecutionContext isolation from stale ambient runtime state.

App identity (`base_path_dir`, `full_target_path`) used to live on
`JacRuntime` as process-global statics that decided each
`ExecutionContext`'s L3 SQLite file. Two clients in the same process
(notably `JacTestClient` instances) need to be isolated from each
other — a stale `full_target_path` from a prior client must not poison
the L3 filename of a freshly-created context.

These tests pin the contract: an ExecutionContext's persistence path is
decided by its own per-context base_path/target_path, captured at
construction time. The pre-context seeds (`Jac.set_base_path` /
`Jac.set_full_target_path`) only feed contexts that don't get explicit
values; subsequent seed mutations cannot poison a live ctx.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.server.session { Session }
import from jaclang.runtime.runtime { JacRuntime }

node RequestValue {
    has value: int = 1;
}

test "persistent field writes mark the active request memory dirty" {
    import from jaclang.runtime.memory { Memory }
    original = JacRuntime.exec_ctx;
    outer = ExecutionContext(_parent=JacRuntime.get_context());
    outer.mem = Memory();
    request = ExecutionContext(_parent=outer);
    request.mem = Memory();
    JacRuntime.exec_ctx = outer;
    token = JacRuntime.push_request_context(request);
    try {
        item = RequestValue();
        JacRuntime.save(item);
        request.mem.commit();
        item.value = 2;
        assert item.value == 2;
        assert item.__jac__.id in request.mem._dirty;
        assert not outer.mem._dirty;
    } finally {
        JacRuntime.reset_request_context(token);
        JacRuntime.exec_ctx = original;
    }
}


test "ExecutionContext uses explicit per-context target_path, ignoring stale seed state" {
    # Standalone .jac files (no jac.toml in their directory) — `get_name`
    # resolves to the filename stem, which gives us two distinct
    # identities to assert on without relying on the JacConfig cache
    # state (which is process-global and out of scope here).
    with TemporaryDirectory() as proj_a, TemporaryDirectory() as proj_b {
        a_target = str(Path(proj_a) / "alpha_app.jac");
        b_target = str(Path(proj_b) / "beta_app.jac");
        orig_base = JacRuntime.get_base_path_dir();
        orig_target = JacRuntime.get_full_target_path();
        orig_ctx = JacRuntime.exec_ctx;
        try {
            # Stale seed state from a hypothetical prior client/CLI run.
            JacRuntime.set_base_path(proj_a);
            JacRuntime.set_full_target_path(a_target);

            # A new context constructed with EXPLICIT per-context base and
            # target — this is the contract a multi-client process needs.
            ctx = ExecutionContext(base_path_dir=proj_b, full_target_path=b_target);

            assert isinstance(ctx.mem, Session);
            loc = ctx.mem.data_location();
            assert loc is not None , "store not initialized";

            # The store identity must reflect beta, not the stale alpha seed.
            assert "beta_app" in loc , f"data location {loc} should reflect 'beta_app'";
            assert "alpha_app" not in loc , f"data location {loc} leaked stale seed 'alpha_app'";

            ctx.close();
        } finally {
            JacRuntime.set_base_path(orig_base);
            JacRuntime.set_full_target_path(orig_target);
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}


test "two ExecutionContexts in one process keep independent persistence paths" {
    with TemporaryDirectory() as proj_a, TemporaryDirectory() as proj_b {
        a_target = str(Path(proj_a) / "alpha_app.jac");
        b_target = str(Path(proj_b) / "beta_app.jac");
        orig_base = JacRuntime.get_base_path_dir();
        orig_target = JacRuntime.get_full_target_path();
        orig_ctx = JacRuntime.exec_ctx;
        try {
            ctx_a = ExecutionContext(base_path_dir=proj_a, full_target_path=a_target);
            ctx_b = ExecutionContext(base_path_dir=proj_b, full_target_path=b_target);

            a_path = ctx_a.mem.data_location();
            b_path = ctx_b.mem.data_location();
            assert a_path is not None;
            assert b_path is not None;

            assert a_path != b_path , "two contexts collapsed onto the same store";
            assert "alpha_app" in a_path;
            assert "beta_app" in b_path;

            ctx_a.close();
            ctx_b.close();
        } finally {
            JacRuntime.set_base_path(orig_base);
            JacRuntime.set_full_target_path(orig_target);
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}


test "ExecutionContext without explicit base/target falls back to JacRuntime seeds" {
    # Back-compat: existing call sites (CLI commands, plugins) that
    # construct `ExecutionContext()` with no args get values from the
    # pre-context seeds set via `Jac.set_base_path` /
    # `Jac.set_full_target_path`.
    with TemporaryDirectory() as tmpdir {
        orig_base = JacRuntime.get_base_path_dir();
        orig_target = JacRuntime.get_full_target_path();
        orig_ctx = JacRuntime.exec_ctx;
        try {
            JacRuntime.set_base_path(tmpdir);
            JacRuntime.set_full_target_path(str(Path(tmpdir) / "standalone.jac"));

            ctx = ExecutionContext();
            assert isinstance(ctx.mem, Session);
            loc = ctx.mem.data_location();
            assert loc is not None;
            # Standalone file (no jac.toml in tmpdir) — get_name() falls back
            # to the filename stem.
            assert "standalone" in loc , f"expected 'standalone' in {loc}";

            ctx.close();
        } finally {
            JacRuntime.set_base_path(orig_base);
            JacRuntime.set_full_target_path(orig_target);
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
