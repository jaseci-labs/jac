# M5.2 — the local build pipeline (cargo fetch -> rustdoc JSON -> binder ->
# cargo build -> install_bridge). The end-to-end build is heavy (compiles a real
# crate) and needs the Rust toolchain + the bridges workspace, so it is gated
# behind JAC_BRIDGE_BUILD_TESTS=1. The cheap guards always run.
import os;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge._builder {
    build_bridge,
    toolchain_available,
    workspace_root
}
import from jaclang.compiler.rust_bridge._finder { find_bridge_lib }


test "missing workspace raises a clear error" {
    # With no workspace resolvable, build_bridge must fail closed with guidance,
    # never a cryptic subprocess error. Pass an explicit bogus workspace so the
    # check fires regardless of the ambient JAC_BRIDGE_WORKSPACE.
    if not toolchain_available() {
        return;
    }
    raised = False;
    try {
        build_bridge("regex", "1.11", workspace="/nonexistent/bridges/workspace");
    } except RuntimeError as e {
        raised = True;
        # jac-bridge lives under the workspace; a bad path can't find it, but the
        # error text still points the user at the right knob.
        assert "jac-bridge" in str(e) or "workspace" in str(e).lower();
    }
    assert raised , "build_bridge must reject an invalid workspace";
}


test "end-to-end build installs a cache-resolvable .so" {
    if os.environ.get("JAC_BRIDGE_BUILD_TESTS") != "1" {
        return;
    }
    if not toolchain_available() or workspace_root() is None {
        return;
    }
    dest = build_bridge("regex", "1.11");
    assert dest.is_file() , f"build_bridge did not produce {dest}";
    assert dest.name == "libjac_bridge_regex.so";
    # the version-scoped cache path the finder resolves, no dev fallback.
    found = find_bridge_lib("regex");
    assert found is not None , "find_bridge_lib could not resolve the built bridge";
    assert found.is_file();
}
