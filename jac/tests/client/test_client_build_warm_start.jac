"""A warm client build over a real project layout compiles nothing.

The unit tests for the client artifact cache drive one module through
`get_client_artifact`. The site that motivated the cache has pages, shared
components in subdirectories, and an entry that imports them, and its warm
build still recompiled everything: the cache root followed the ambient project
config, which is unset during parts of a `jac run`, so entries were written
under the project and looked for beside each module. This test builds such a
project through the client compiler once, then requires a warm build, a warm
build with the ambient config pinned away, and the build after an HMR edit to
enter the compiler only for what actually changed, leaving no cache directory
beside any module.
"""

import os;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.compiler.driver.pass_driver { compile_progress }
import from jaclang.project.config {
    get_config,
    pin_project_scope,
    project_scope_is_pinned,
    set_config
}
import from jaclang.runtime.runtime { JacRuntime as Jac }


glob _BUTTON: str = (
         'def:pub Button(label: str) -> any {\n    return <button>{label}</button>;\n}\n'
     );


"""A web-app with an entry, a shared component tree, and two routed pages."""
def _project -> Path {
    proj = Path(os.path.realpath(tempfile.mkdtemp(prefix="jac_warm_build_")));
    (proj / "jac.toml").write_text('[project]\nname = "warmsite"\nkind = "web-app"\n');
    (proj / "package.json").write_text('{"name":"warmsite","version":"0.0.0"}');
    (proj / "shared" / "ui").mkdir(parents=True);
    (proj / "pages").mkdir();
    (proj / "shared" / "ui" / "button.jac").write_text(_BUTTON);
    (proj / "shared" / "Navbar.jac").write_text(
        'import from .ui.button { Button }\n\n'
        'def:pub Navbar() -> any {\n    return <nav><Button label="home" /></nav>;\n}\n'
    );
    (proj / "pages" / "index.jac").write_text(
        'import from ..shared.Navbar { Navbar }\n\n'
        'def:pub page -> JsxPage {\n    return <div><Navbar /></div>;\n}\n'
    );
    (proj / "pages" / "about.jac").write_text(
        'def:pub page -> JsxPage {\n    return <p>about</p>;\n}\n'
    );
    (proj / "main.jac").write_text(
        'import from .shared.Navbar { Navbar }\n\n'
        'def:pub app(children: any = None) -> any {\n    return <main><Navbar />{children}</main>;\n}\n'
    );
    return proj;
}


"""The project's client compiler, writing under `out`."""
def _compiler(proj: Path) -> any {
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }
    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler();
    compiler.jac_client_compiler.compiled_dir = proj / "out";
    return compiler;
}


"""Run the client build; return the modules that entered the compiler."""
def _build(proj: Path) -> list[str] {
    seen: list[str] = [];
    with compile_progress.listen(seen.append) {
        _compiler(proj).jac_client_compiler.compile(None, proj / "main.jac");
    }
    return [os.path.basename(p) for p in seen];
}


"""Rewrite `path`, stamped clearly later than any cache file."""
def _edit(path: Path, text: str) {
    path.write_text(text);
    later = time.time() + 5.0;
    os.utime(str(path), (later, later));
}


"""Cache directories that landed beside a module instead of under the project."""
def _stray_caches(proj: Path) -> list[str] {
    return [
        str(p.relative_to(proj))
        for p in proj.rglob(".jac")
        if p.is_dir() and p.parent != proj
    ];
}


test "a warm client build over a real layout is served from the cache" {
    import from jaclang.server.hmr { HotReloader }
    import from jaclang.server.watcher { JacFileWatcher }
    proj = _project();

    cold = _build(proj);
    for name in ["main.jac", "Navbar.jac", "button.jac", "index.jac", "about.jac"] {
        assert name in cold , f"the cold build must compile {name}, saw {cold}";
    }
    warm = _build(proj);
    assert warm == [] , f"the warm build must be served from the cache, compiled {warm}";

    pinned = project_scope_is_pinned();
    saved = get_config();
    try {
        pin_project_scope(None);
        unconfigured = _build(proj);
    } finally {
        if pinned {
            pin_project_scope(saved);
        } else {
            set_config(None);
            get_config(force_discover=True);
        }
    }
    assert unconfigured == [] , (
        f"with no ambient config the warm build must still find its cache, "
        f"compiled {unconfigured}"
    );
    assert _stray_caches(proj) == [] , (
        f"cache entries must live under the project, found {_stray_caches(proj)}"
    );

    button = proj / "shared" / "ui" / "button.jac";
    _edit(button, _BUTTON.replace("{label}", "clicked {label}"));
    reloader = HotReloader(
        base_path=str(proj),
        module_name="main",
        watcher=JacFileWatcher(watch_paths=[str(proj)]),
        client_compiler=_compiler(proj)
    );
    reloader._running = True;
    edited: list[str] = [];
    with compile_progress.listen(edited.append) {
        reloader._recompile_client_unified(str(button));
    }
    assert any(p.endswith("button.jac") for p in edited) , (
        f"an HMR edit must recompile the edited module, saw {edited}"
    );
    assert "clicked" in (proj / "out" / "shared" / "ui" / "button.js").read_text() , (
        "the HMR output must carry the edit"
    );

    Jac.get_program().hub.reset();
    after = _build(proj);
    assert "Navbar.jac" in after , (
        f"the module that imports the edited one must recompile, saw {after}"
    );
    for name in ["main.jac", "index.jac", "about.jac"] {
        assert name not in after , (
            f"{name} imports nothing that changed and must be served, saw {after}"
        );
    }
    assert _build(proj) == [] , "the build after that must be fully served again";
}

test "a pages entry whose app cannot receive the route tree is refused" {
    # The generated entry renders `app` with the routes as its children; an
    # `app` without `children` would drop every page, so the build stops here.
    import from jaclang.client.client_bundle { ClientBundleError }
    proj = _project();
    (proj / "main.jac").write_text(
        'def:pub app -> JsxElement {\n    return <main>shell</main>;\n}\n'
    );
    refused = False;
    try {
        _compiler(proj).jac_client_compiler.compile(None, proj / "main.jac");
    } except ClientBundleError as e {
        refused = "children" in str(e);
    }
    assert refused , "an app that drops the route tree must fail the client build";
}
