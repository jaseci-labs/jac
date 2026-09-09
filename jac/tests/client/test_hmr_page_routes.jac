"""Adding or removing a page during a dev session must reach the browser.

A page file that appears while `jac run --dev` is watching gets compiled, but
the route table it belongs to lives in a separate generated module
(`_routes.js`) that the entry imports once. Regenerating that file is not
enough on its own: the router in the page already captured its route array at
mount, so the new URL keeps rendering nothing until someone restarts the
server. The dev loop already owns a full-reload signal (`.jac-force-reload`,
used when a module's export set changes); a changed route table is exactly the
same class of change and must raise it.
"""

import os;
import shutil;
import from pathlib { Path }
import from tempfile { mkdtemp }

import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
import from jaclang.server.hmr { HotReloader }
import from jaclang.server.watcher { JacFileWatcher }


def _write(path: str, body: str) {
    os.makedirs(os.path.dirname(path), exist_ok=True);
    Path(path).write_text(body, encoding="utf-8");
}


"""A page-routed web app with one route, compiled once the way the dev server
compiles it at startup. Returns (project_root, hot_reloader, routes_file)."""
def _booted_project -> tuple[(str, any, str)] {
    proj = mkdtemp(prefix="jacroutes-");
    _write(
        os.path.join(proj, "jac.toml"),
        '[project]\nname = "site"\nkind = "web-app"\nentry-point = "main.jac"\n'
    );
    _write(
        os.path.join(proj, "main.jac"),
        'def:pub page -> JsxPage {\n    return <div>home</div>;\n}\n'
    );
    _write(
        os.path.join(proj, "pages", "index.jac"),
        'def:pub page -> JsxPage {\n    return <div>home</div>;\n}\n'
    );
    builder = make_client_bundle_builder(base_path=Path(proj));
    compiler = builder._get_compiler();
    jcc = compiler.jac_client_compiler;
    compiler._has_pages = jcc._scan_and_compile_pages();
    compiler.create_entry_file(Path(os.path.join(proj, "main.jac")));
    reloader = HotReloader(
        base_path=proj,
        module_name="main",
        watcher=JacFileWatcher(watch_paths=[proj]),
        client_compiler=compiler
    );
    reloader._running = True;
    routes_file = os.path.join(str(jcc.compiled_dir), "_routes.js");
    return (proj, reloader, routes_file);
}


def _reload_signal(project_dir: str) -> Path {
    return Path(project_dir) / ".jac" / "client" / ".jac-force-reload";
}


test "a page created during the session joins the route table" {
    (proj, reloader, routes_file) = _booted_project();
    try {
        before = Path(routes_file).read_text(encoding="utf-8");
        new_page = os.path.join(proj, "pages", "[...lost].jac");
        _write(new_page, 'def:pub page -> JsxPage {\n    return <div>lost</div>;\n}\n');
        reloader._process_change(new_page);
        after = Path(routes_file).read_text(encoding="utf-8");
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert "[...lost]" not in before , "fixture should start without the new route";
    assert "[...lost]" in after , (
        f"a page added during the session must join _routes.js; got:\n{after}"
    );
    assert 'path: "/*"' in after , (
        f"the catch-all page must claim its URL; got:\n{after}"
    );
}


test "a changed route table forces a browser reload" {
    (proj, reloader, routes_file) = _booted_project();
    try {
        signal = _reload_signal(proj);
        if signal.exists() {
            signal.unlink();
        }
        new_page = os.path.join(proj, "pages", "about.jac");
        _write(
            new_page, 'def:pub page -> JsxPage {\n    return <div>about</div>;\n}\n'
        );
        reloader._process_change(new_page);
        raised = signal.exists();
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert raised , (
        "the router captured its routes at mount, so a new route only takes "
        "effect after a full reload; the watcher must raise the signal"
    );
}


test "an edit that leaves the route table alone does not force a reload" {
    (proj, reloader, routes_file) = _booted_project();
    try {
        signal = _reload_signal(proj);
        if signal.exists() {
            signal.unlink();
        }
        index = os.path.join(proj, "pages", "index.jac");
        _write(
            index, 'def:pub page -> JsxPage {\n    return <div>home two</div>;\n}\n'
        );
        reloader._process_change(index);
        raised = signal.exists();
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert not raised , (
        "editing a page body is what hot replacement is for; only a changed "
        "route table costs a full reload"
    );
}


test "removing a page drops its route and forces a reload" {
    (proj, reloader, routes_file) = _booted_project();
    try {
        extra = os.path.join(proj, "pages", "about.jac");
        _write(extra, 'def:pub page -> JsxPage {\n    return <div>about</div>;\n}\n');
        reloader._process_change(extra);
        signal = _reload_signal(proj);
        if signal.exists() {
            signal.unlink();
        }
        os.remove(extra);
        reloader._process_change(extra);
        after = Path(routes_file).read_text(encoding="utf-8");
        raised = signal.exists();
    } finally {
        shutil.rmtree(proj, ignore_errors=True);
    }
    assert "about" not in after , (
        f"a removed page must lose its route; got:\n{after}"
    );
    assert raised , "dropping a route must reach the browser too";
}
