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
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.memory { TieredMemory }
import from jaclang.jac0core.runtime { JacRuntime }


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

            assert isinstance(ctx.mem, TieredMemory);
            l3 = ctx.mem.l3;
            assert l3 is not None , "L3 not initialized";
            l3_path = l3.path;

            # The L3 file must live under proj_b and use beta's identity.
            assert proj_b in l3_path , f"L3 path {l3_path} not under proj_b";
            assert "beta_app" in os.path.basename(l3_path) , f"L3 filename {l3_path} should reflect 'beta_app'";
            assert "alpha_app" not in l3_path , f"L3 path {l3_path} leaked stale seed 'alpha_app'";

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

            a_path = ctx_a.mem.l3.path;
            b_path = ctx_b.mem.l3.path;

            assert a_path != b_path , "two contexts collapsed onto the same L3 file";
            assert proj_a in a_path and "alpha_app" in os.path.basename(a_path);
            assert proj_b in b_path and "beta_app" in os.path.basename(b_path);

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
            assert isinstance(ctx.mem, TieredMemory);
            l3_path = ctx.mem.l3.path;
            assert tmpdir in l3_path , f"expected {tmpdir} in {l3_path}";
            # Standalone file (no jac.toml in tmpdir) — get_name() falls back
            # to the filename stem.
            assert "standalone" in os.path.basename(l3_path) , f"expected 'standalone' in basename of {l3_path}";

            ctx.close();
        } finally {
            JacRuntime.set_base_path(orig_base);
            JacRuntime.set_full_target_path(orig_target);
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
