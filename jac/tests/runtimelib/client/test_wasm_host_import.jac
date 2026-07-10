"""Regression test for issue #7189: `@jac/wasm_host` must resolve in the vite
fullstack client build.

na->wasm modules link against the versioned `jac_host1` import contract added
in #7136; the client shim obtains that host object from `@jac/wasm_host`. A
fullstack app whose `.cl`/`cl {}` code imports `@jac/wasm_host` must therefore
build. Before the fix the vite client build materialized no provider and added
no alias for the specifier, so `jac build` failed with a Rollup
"[vite]: Rollup failed to resolve import \"@jac/wasm_host\"" error and shipped
no dist -- breaking jaseci's own `examples/raylib_shooter/web` example.

The client dependency-compiler already materializes the imported provider at
`compiled/wasm_host.js`; the fix aliases `@jac/wasm_host` to it in both the
build and dev-server vite configs, mirroring how `@jac/runtime`/`@jac/desktop`
are aliased.
"""

import os;
import tempfile;
import pytest;
import from subprocess { run }

import from .test_helpers { copy_fixture, get_env_with_bun, get_jac_command }

"""A fullstack client importing @jac/wasm_host builds and ships a dist.

Reproduces the exact failure path from #7189: the `cl {}` block imports
`instantiate_na_wasm` from `@jac/wasm_host`. Asserts (1) `jac build` succeeds,
(2) the provider is materialized at `compiled/wasm_host.js`, and (3) a client
bundle actually ships to `dist/`.
"""
test "fullstack client importing @jac/wasm_host builds" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = copy_fixture("wasm_host_app", temp_dir);
        jac_cmd = get_jac_command();
        env = get_env_with_bun();
        add_result = run(
            [*jac_cmd, "install", "--npm"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
        );
        if add_result.returncode != 0 {
            pytest.fail(
                f"jac install --npm failed (bun/npm unavailable?)\n"
                f"STDOUT:\n{add_result.stdout[:2000]}\n"
                f"STDERR:\n{add_result.stderr[:2000]}\n"
            );
        }
        build_result = run(
            [*jac_cmd, "build", "--client", "web", "main.jac"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
        );
        assert build_result.returncode == 0 , (
            f"jac build should resolve @jac/wasm_host and succeed\n"
            f"STDOUT:\n{build_result.stdout[:2000]}\n"
            f"STDERR:\n{build_result.stderr[:2000]}\n"
        );
        wasm_host_js = os.path.join(
            project_dir, ".jac", "client", "compiled", "wasm_host.js"
        );
        assert os.path.isfile(wasm_host_js) , (
            f"@jac/wasm_host provider should be materialized at {wasm_host_js}"
        );
        dist_dir = os.path.join(project_dir, ".jac", "client", "dist");
        assert os.path.isdir(dist_dir) , (
            f"client bundle should ship a dist at {dist_dir}"
        );
        dist_files = os.listdir(dist_dir);
        assert any([f.endswith(".js") for f in dist_files]) , (
            f"dist should contain a JS bundle, got: {dist_files}"
        );
    }
}
