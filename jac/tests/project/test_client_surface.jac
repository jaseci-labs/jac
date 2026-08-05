"""Tests for resolve_client_surface — the single client-surface resolver.

resolve_client_surface is the one authority that both the type checker's
ambient-vocabulary gates and the ES backend selection consult, so the two can
never disagree on which rendering surface a module targets. These pin the
precedence: an active target's CompileOptions.client_framework override wins
unconditionally, and only with no override does the per-module disk config
(`[client] framework`) decide.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.project.client_kind { resolve_client_surface }

def _project_with_toml(body: str) -> Path {
    d = Path(tempfile.mkdtemp(prefix="jac_test_client_surface_"));
    (d / "jac.toml").write_text(body);
    return d;
}

test "compose framework override wins regardless of disk config" {
    d = _project_with_toml("[client]\nframework = \"react\"\n");
    mod_path = str(d / "page.jac");
    surface = resolve_client_surface(mod_path, "compose");
    assert surface.framework == "compose";
    assert surface.is_compose == True;
}

test "no override falls back to disk config framework" {
    d = _project_with_toml("[client]\nframework = \"react\"\n");
    mod_path = str(d / "page.jac");
    surface = resolve_client_surface(mod_path, "");
    assert surface.framework == "react";
    assert surface.is_compose == False;
}

test "no override on a compose project resolves compose surface" {
    d = _project_with_toml("[client]\nframework = \"compose\"\n");
    mod_path = str(d / "page.jac");
    surface = resolve_client_surface(mod_path, "");
    assert surface.framework == "compose";
    assert surface.is_compose == True;
}

test "non-compose override clears is_compose even on compose project" {
    d = _project_with_toml("[client]\nframework = \"compose\"\n");
    mod_path = str(d / "page.jac");
    surface = resolve_client_surface(mod_path, "solid");
    assert surface.framework == "solid";
    assert surface.is_compose == False;
}

test "framework defaults to react with no override and no config" {
    d = _project_with_toml("[project]\nname = \"demo\"\n");
    mod_path = str(d / "page.jac");
    surface = resolve_client_surface(mod_path, "");
    assert surface.framework == "react";
    assert surface.is_compose == False;
}
