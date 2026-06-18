"""Tests for kind-aware `jac create`.

`jac create --kind <kind>` scaffolds a project for a specific project kind:
it stamps `[project] kind` into jac.toml, lays down an entry-point in the
right codespace, and produces a project whose bare `jac run` resolves to the
natural action for that kind. These tests cover the eight core kinds (the
plugin kinds -- fullstack/client/mobile/desktop -- are tested in their own
plugin packages)."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { JacConfig }
import from jaclang.project.kinds { plan_project_run, is_valid_kind, kind_entry }
import from jaclang.project.template_registry { initialize_template_registry }

glob _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

"""Scaffold a project of `kind` in a throwaway dir; return its project path."""
def _scaffold(kind: str) -> Path {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jaccreate_");
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

"""A scaffolded project stamps its kind, lays its entry file, and round-trips
through the run planner to the expected action."""
def _assert_kind(kind: str, entry_name: str, action: str) {
    proj = _scaffold(kind);
    toml = (proj / "jac.toml").read_text();
    assert f'kind = "{kind}"' in toml , f"[project] kind not stamped for {kind}";
    if entry_name {
        assert (proj / entry_name).exists() , f"entry {entry_name} missing for {kind}";
    }
    cfg = JacConfig.discover(start_path=proj);
    assert cfg is not None;
    assert cfg.project.kind == kind;
    plan = plan_project_run(cfg, str(proj));
    assert plan is not None , f"no run plan for {kind}";
    assert plan.action == action , f"{kind}: expected {action}, got {plan.action}";
}

test "create --kind cli" {
    _assert_kind("cli", "main.jac", "execute");
    _cleanup();
}

test "create --kind native-app" {
    _assert_kind("native-app", "main.na.jac", "execute");
    _cleanup();
}

test "create --kind native-binary" {
    _assert_kind("native-binary", "main.na.jac", "build");
    _cleanup();
}

test "create --kind shared-library" {
    _assert_kind("shared-library", "main.na.jac", "build");
    _cleanup();
}

test "create --kind api-service" {
    _assert_kind("api-service", "main.sv.jac", "serve");
    _cleanup();
}

test "create --kind microservices" {
    _assert_kind("microservices", "main.sv.jac", "serve");
    _cleanup();
}

test "create --kind pypi-package" {
    _assert_kind("pypi-package", "lib.jac", "build");
    _cleanup();
}

test "create --kind npm-package" {
    _assert_kind("npm-package", "lib.jac", "build");
    _cleanup();
}

test "bare create defaults to cli kind" {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jaccreate_");
    _tmp_dirs.append(d);
    os.chdir(d);
    rc = project.create(name="app", force=True);
    os.chdir(_orig_cwd);
    assert rc == 0;
    toml = (Path(d) / "app" / "jac.toml").read_text();
    assert 'kind = "cli"' in toml;
    _cleanup();
}

test "create rejects an unknown kind" {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jaccreate_");
    _tmp_dirs.append(d);
    os.chdir(d);
    rc = project.create(name="app", kind="not-a-kind", force=True);
    os.chdir(_orig_cwd);
    assert rc != 0 , "unknown kind should fail";
    _cleanup();
}

test "kind_entry matches the scaffolded entry-point" {
    assert kind_entry("cli") == "main.jac";
    assert kind_entry("native-app") == "main.na.jac";
    assert kind_entry("api-service") == "main.sv.jac";
    assert is_valid_kind("cli");
    assert not is_valid_kind("nope");
}
