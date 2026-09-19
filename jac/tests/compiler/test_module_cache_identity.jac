"""A module's cache key is a function of the module, not of the compile that reached it.

The key mixed two half-identities. One was derived from the module's own path
(`_project_env_fingerprint`: resolved codespace, placement pins, app facts, the
workspace digest); the other was `cache_identity()`, an ambient string set per
compile invocation and carrying `options.entry_point`. `bind_options` copies the
root's entry point onto every dependency it binds, so the ambient half named the
file the user typed on the command line, and every module the compile reached
was keyed under it.

One unedited module therefore got a fresh cache entry per `check`/`test`/`run`
target: the cache grew with targets x modules, and every new target re-paid a
cold analysis of the whole shared closure (#9284).

The projection the key uses is now derived from the module's own path and its
owning program's bound options, and never reads an entry point, so a module
reached from two entry points lands on one entry. Apps stay apart on their own:
`app` and `app_kind` are terms of both `analysis_identity` and
`codegen_identity`, so a module shared by two apps still keys once per app.
"""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { cache_scope }
import from jaclang.compiler.driver.jir { get_module_cache_path, module_cache_key }
import from jaclang.project.config {
    get_config,
    get_config_for_path,
    pin_project_scope,
    project_scope_is_pinned,
    set_config
}


def _project(prefix: str, toml: str) -> Path {
    base = Path(os.path.realpath(tempfile.mkdtemp(prefix=prefix)));
    (base / "jac.toml").write_text(toml);
    (base / "shared.jac").write_text("def two -> int {\n    return 2;\n}\n");
    for name in ["a", "b"] {
        (base / f"{name}.jac").write_text(
            "import from shared { two }\n\nwith entry {\n    print(two());\n}\n"
        );
    }
    return base;
}


def _keyed_as(base: Path, rooted_at: str, **extra: any) -> tuple[Path, str] {
    # Key `shared.jac` the way a compile rooted at `rooted_at` keys it.
    options = CompileOptions(
        entry_point=str(base / f"{rooted_at}.jac"), project_root=str(base), **extra
    );
    with cache_scope(options) {
        target = str(base / "shared.jac");
        return (get_module_cache_path(target), module_cache_key(target));
    }
}


test "a module reached from two entry points is cached once" {
    base = _project("jac_cache_identity_", '[project]\nname = "shared_closure"\n');
    pinned = project_scope_is_pinned();
    saved = get_config();
    try {
        pin_project_scope(get_config_for_path(base));
        (path_a, key_a) = _keyed_as(base, "a");
        (path_b, key_b) = _keyed_as(base, "b");
    } finally {
        if pinned {
            pin_project_scope(saved);
        } else {
            set_config(None);
            get_config(force_discover=True);
        }
    }
    assert path_a == path_b , (
        "one unedited module must occupy one cache entry however it was reached; "
        f"checking a.jac put it at {path_a.name} and b.jac at {path_b.name}"
    );
    assert key_a == key_b , (
        "the in-JIR module key gates reuse, so it must match the path: "
        f"{key_a} vs {key_b}"
    );
}


test "two apps sharing a module keep an entry each" {
    # Placement, and so compiled output, can differ per app. The entry point is
    # gone from the projection; app identity must not follow it out.
    base = _project(
        "jac_cache_apps_",
        '[project]\nname = "two_apps"\n\n'
        '[apps.web]\nkind = "service"\nentry-point = "a"\n\n'
        '[apps.jobs]\nkind = "service"\nentry-point = "b"\n'
    );
    pinned = project_scope_is_pinned();
    saved = get_config();
    try {
        pin_project_scope(get_config_for_path(base));
        (path_web, key_web) = _keyed_as(
            base, "a", target_app="web", app_kind="service"
        );
        (path_jobs, key_jobs) = _keyed_as(
            base, "b", target_app="jobs", app_kind="service"
        );
    } finally {
        if pinned {
            pin_project_scope(saved);
        } else {
            set_config(None);
            get_config(force_discover=True);
        }
    }
    assert path_web != path_jobs , (
        "a module compiled for one app must not be served to another: "
        f"both apps landed on {path_web.name}"
    );
    assert key_web != key_jobs , (
        f"the in-JIR module key must separate apps too: {key_web} vs {key_jobs}"
    );
}
