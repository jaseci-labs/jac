"""Tests for jac-client's kind-aware `jac create` templates.

jac-client contributes the project kinds it owns -- `fullstack`, `wasm`, and
`mobile` -- to the kind-aware `jac create`. Each scaffolds with `[project]
kind` stamped and the right entry-point. npm/Bun install is skipped via
JAC_CLIENT_SKIP_NPM_INSTALL so the scaffold is offline and fast."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { JacConfig }
import from jaclang.project.kinds { plan_project_run }
import from jaclang.project.template_registry { initialize_template_registry }

glob _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

def _scaffold(kind: str) -> Path {
    os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jacclientkind_");
    _tmp_dirs.append(d);
    os.chdir(d);
    rc = project.create(name="app", kind=kind, force=True);
    os.chdir(_orig_cwd);
    assert rc == 0 , f"create --kind {kind} returned {rc}";
    return Path(d) / "app";
}

def _cleanup {
    os.chdir(_orig_cwd);
    for d in _tmp_dirs {
        shutil.rmtree(d, ignore_errors=True);
    }
    _tmp_dirs.clear();
}

def _assert_kind(kind: str, action: str) {
    proj = _scaffold(kind);
    toml = (proj / "jac.toml").read_text();
    assert f'kind = "{kind}"' in toml , f"[project] kind not stamped for {kind}";
    assert (proj / "main.jac").exists() , f"main.jac missing for {kind}";
    cfg = JacConfig.discover(start_path=proj);
    assert cfg.project.kind == kind;
    plan = plan_project_run(cfg, str(proj));
    assert plan is not None;
    assert plan.action == action , f"{kind}: expected {action}, got {plan.action}";
}

test "create --kind fullstack" {
    _assert_kind("fullstack", "serve");
    _cleanup();
}

test "create --kind client" {
    _assert_kind("client", "serve");
    _cleanup();
}

test "create --kind mobile" {
    _assert_kind("mobile", "build");
    _cleanup();
}
