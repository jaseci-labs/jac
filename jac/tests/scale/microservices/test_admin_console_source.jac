"""A pinned deploy should ship the admin console its version publishes.

The LOCAL channel means "do not fetch a binary, I brought one". That guarantee
was applied to the admin console too, so a LOCAL deploy pinned to a released
version staged no console and every gateway pod rebuilt it from source on every
boot: minutes of npm and vite work before the gateway listened, which reads as
the app serving 503 under a rollout that does not keep the old pod.
"""

import os;
import from pathlib { Path }
import from tempfile { mkdtemp }
import from jaclang.scale.injector.binary {
    admin_dist_source,
    resolve_console_version,
    resolve_deploy_version,
    resolve_pinned_version
}


def _project(toml_body: str) -> str {
    proj = mkdtemp();
    Path(os.path.join(proj, "jac.toml")).write_text(toml_body);
    Path(os.path.join(proj, "main.jac")).write_text("with entry {\n    print(1);\n}\n");
    return proj;
}


test "the dev channel keeps its rolling console asset" {
    assert admin_dist_source("dev", "") == "dev";
    assert admin_dist_source("dev", "0.34.9") == "dev";
}


test "a local deploy with a resolved version fetches the pinned console" {
    assert admin_dist_source("local", "0.34.9") == "release";
}


test "a local deploy with no version still fetches nothing" {
    assert admin_dist_source("local", "") == "";
}


test "the stable channel is unchanged in both directions" {
    assert admin_dist_source("stable", "") == "release";
    assert admin_dist_source("stable", "0.34.9") == "release";
}


test "an already resolved deploy version is used as it stands" {
    proj = _project('[project]\nname = "app"\n');
    assert resolve_console_version(proj, "stable", "0.36.1") == "0.36.1";
    assert resolve_console_version(proj, "local", "0.36.1") == "0.36.1";
}


test "an unpinned project resolves to no console version on any channel" {
    proj = _project('[project]\nname = "app"\n');
    assert resolve_pinned_version(proj) == "";
    assert resolve_console_version(proj, "local", "") == "";
    assert resolve_console_version(proj, "dev", "") == "";
    assert resolve_console_version(proj, "stable", "") == "";
}


test "the deploy version stays stable-only, so local never fetches a binary" {
    proj = _project('[project]\nname = "app"\n');
    assert resolve_deploy_version(proj, "local") == "";
    assert resolve_deploy_version(proj, "dev") == "";
}
