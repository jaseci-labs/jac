"""Tests for kind-aware `jac create`.

`jac create --kind <kind>` scaffolds a project for a specific kind: it stamps
`[project] kind` into jac.toml (or, for a scaffold that is already an app,
an explicit `[apps.<name>]` table), lays down an entry-point in the right
codespace, and produces a project whose bare `jac run` resolves to the natural
action for that kind. Every kind of the KIND_SPECS table is covered here."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { project }
import from jaclang.project.config { JacConfig }
import from jaclang.project.kinds { plan_app_run, is_valid_kind, kind_entry }
import from jaclang.project.template_registry { initialize_template_registry }

glob _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

"""Scaffold a project of `kind` in a throwaway dir; return its project path."""
def _scaffold(kind: str) -> Path {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jaccreate_");
    _tmp_dirs.append(d);
    os.chdir(d);
    # Scaffold only — create-time dep install needs network and is not under test.
    rc = project.create(name="app", kind=kind, force=True, `skip=True);
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
    assert not cfg.is_workspace , f"{kind} scaffold is a single-app project";
    assert cfg.project.kind == kind;
    app = cfg.resolve_app("");
    assert app.implicit and app.kind == kind;
    plan = plan_app_run(cfg, str(proj), app);
    assert plan is not None , f"no run plan for {kind}";
    assert plan.action == action , f"{kind}: expected {action}, got {plan.action}";
    assert plan.app == "" , "an implicit app plans without an app name";
}

test "create --kind cli" {
    _assert_kind("cli", "main.jac", "execute");
    _cleanup();
}

test "create --kind cli-native" {
    _assert_kind("cli-native", "main.jac", "execute");
    _cleanup();
}

test "create --kind native-binary" {
    _assert_kind("native-binary", "main.jac", "build");
    _cleanup();
}

test "create --kind native-lib" {
    _assert_kind("native-lib", "main.jac", "build");
    _cleanup();
}

test "create --kind service" {
    _assert_kind("service", "main.jac", "serve");
    _cleanup();
}

test "create --kind service-mesh" {
    _assert_kind("service-mesh", "main.jac", "serve");
    _cleanup();
}

test "create --kind py-package" {
    _assert_kind("py-package", "lib.jac", "build");
    _cleanup();
}

test "create --kind js-package" {
    _assert_kind("js-package", "lib.jac", "build");
    _cleanup();
}

test "create --kind web-app" {
    _assert_kind("web-app", "main.jac", "serve");
    _cleanup();
}

test "create --kind web-static" {
    _assert_kind("web-static", "main.jac", "serve");
    _cleanup();
}

test "create --kind desktop" {
    _assert_kind("desktop", "main.jac", "serve");
    _cleanup();
}

test "create --kind mobile scaffolds a single-app mobUI project" {
    proj = _scaffold("mobile");
    toml = (proj / "jac.toml").read_text();
    assert "[apps." not in toml , "a single-app scaffold uses the [project] sugar";
    assert 'kind = "mobile"' in toml;
    assert (proj / "main.jac").exists();
    assert (proj / "theme.jac").exists();
    assert (proj / "screens" / "Home.jac").exists();
    cfg = JacConfig.discover(start_path=proj);
    assert cfg is not None;
    assert not cfg.is_workspace;
    assert cfg.project.kind == "mobile";
    app = cfg.resolve_app("");
    assert app.implicit;
    assert app.kind == "mobile";
    assert app.ui() == "mobui" , "a mobile app is mobUI by kind alone";
    assert not hasattr(app, "client") and not hasattr(app, "client_kind") , (
        "the scaffolded app carries no client axis"
    );
    assert "client =" not in toml and "client_kind" not in toml , (
        "the scaffold writes no client / client_kind keys"
    );
    plan = plan_app_run(cfg, str(proj), app);
    assert plan.action == "build" , f"mobile: expected build, got {plan.action}";
    assert plan.app == "" , "an implicit app runs without an app positional";
    assert "client" not in plan.flags , "the plan carries no client flag";
    assert plan.spec.ui == "mobui";
    assert plan.command_line() == "jac build main.jac" , plan.command_line();
    assert plan.entry_path.endswith("main.jac") , plan.entry_path;
    _cleanup();
}

test "bare create defaults to cli kind" {
    initialize_template_registry();
    d = tempfile.mkdtemp(prefix="jaccreate_");
    _tmp_dirs.append(d);
    os.chdir(d);
    rc = project.create(name="app", force=True, `skip=True);
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
    assert kind_entry("cli-native") == "main.jac";
    assert kind_entry("service") == "main.jac";
    assert kind_entry("mobile") == "main.jac";
    assert is_valid_kind("cli");
    assert is_valid_kind("service");
    assert is_valid_kind("mobile");
    assert not is_valid_kind("nope");
}
