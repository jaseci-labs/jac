"""Tests for the client-kind split between the config lane and the pure lane.

`client_kind_paths` is the half a compiler pass imports at module scope, so it
has to stay free of `jaclang.project.config`: a pass that drags the config lane
into its native closure cannot lower, because resolving a config is Python-side
driver work. `client_kind` keeps the resolution and may stay Python-only.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.client_kind_paths { mobui_enforced_in, mobui_module_exempt }
import jaclang.project.client_kind_paths as pure_mod;

test "a module under the project root is not exempt" {
    with TemporaryDirectory() as td {
        proj_root = os.path.join(td, "proj");
        os.makedirs(os.path.join(proj_root, "src"));
        mod_path = os.path.join(proj_root, "src", "app.jac");
        assert not mobui_module_exempt(mod_path, proj_root);
    }
}

test "a module outside the project root is exempt" {
    with TemporaryDirectory() as td {
        proj_root = os.path.join(td, "proj");
        other = os.path.join(td, "other");
        os.makedirs(proj_root);
        os.makedirs(other);
        assert mobui_module_exempt(os.path.join(other, "app.jac"), proj_root);
    }
}

test "no project root means every module is exempt" {
    assert mobui_module_exempt("/anywhere/app.jac", None);
    assert mobui_module_exempt("/anywhere/app.jac", "");
}

test "enforcement needs both the mobui kind and a containing root" {
    with TemporaryDirectory() as td {
        proj_root = os.path.join(td, "proj");
        os.makedirs(os.path.join(proj_root, "src"));
        mod_path = os.path.join(proj_root, "src", "app.jac");
        assert mobui_enforced_in(mod_path, "mobui", proj_root);
        assert not mobui_enforced_in(mod_path, "web", proj_root);
        assert not mobui_enforced_in(mod_path, "mobui", None);
    }
}

test "the pure lane names no project config" {
    src = Path(pure_mod.__file__).read_text();
    assert "jaclang.project.config" not in src , (
        "client_kind_paths grew a project-config dependency; that puts the "
        "config lane back into every pass closure that imports it. Resolution "
        "belongs in client_kind."
    );
}
