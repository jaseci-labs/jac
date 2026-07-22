"""Route-scanner membership tests for the file-based router.

Locks in the root-cause fix for #7640: whether a `pages/` file becomes a route
is decided by the top-level symbols the module defines (a route defines `page`,
a layout defines `layout`), not by a filename skip-suffix. This lets a markerless
co-located component live beside its route in `pages/` without being
auto-registered as a broken route.

The scanner takes an injected `symbols_of` resolver (in production it is backed
by the client compiler's compiled symbol table). Here the resolver reads the
written source and reports the defined `def` names, standing in for
`mod.sym_tab.names_in_scope`. Route symbols (`page` / `layout`) are detected
whether or not the def is `:pub`, because the generated router imports them by
name regardless.
"""

import re;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.runtimelib.client.route_scanner { RouteScanner }


"""Write `body` to `base/rel`, creating parent directories."""
def _write(base: Path, rel: str, body: str) -> Path {
    target = base / rel;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(body, encoding='utf-8');
    return target;
}


"""Stand-in for the module's compiled `sym_tab.names_in_scope`.

Reports the top-level `def` names a module declares (with or without `:pub`) so
the scanner can decide route membership from what the module defines.
"""
def _symbols_from_source(path: Path) -> (list[str] | None) {
    try {
        text = path.read_text(encoding='utf-8');
    } except OSError {
        return None;
    }
    return re.findall(r'def(?::\w+)?\s+(\w+)\s*\(', text);
}


"""A resolver that never resolves (simulates a page that fails to compile)."""
def _unresolvable(path: Path) -> (list[str] | None) {
    return None;
}


"""Return the non-layout route paths a scan produced."""
def _route_paths(scanner: RouteScanner) -> set[str] {
    routes = scanner.scan();
    return {
        route.path
        for route in routes
        if not route.is_layout
    };
}


"""A page and its markerless co-located component both live in pages/.

The component (`budget_ui.jac`, plain `.jac`, no marker) defines `BudgetUI`,
not `page`, so it must not become a route. Before the fix the scanner keyed off
the `.cl.` skip-suffix and auto-registered this plain `.jac` as a broken
`/budget_ui` route."""
test "markerless co-located component is not auto-registered as a route" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/budget.jac",
            "def:pub page() -> JsxElement { return <BudgetUI />; }",
        );
        _write(
            proj,
            "pages/budget_ui.jac",
            "def:pub BudgetUI() -> JsxElement { return <div>ui</div>; }",
        );
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/budget"} , f"co-located component should not be a route; got {paths}";
        page_names = {pf.name for pf in scanner.get_page_files()};
        assert "budget_ui.jac" not in page_names , "co-located component should not be compiled as a page";
    }
}


"""A page defined non-`pub` inside an explicit `cl {}` block is still a route.

`manifest.exports` only lists `:pub` symbols, so keying on exports drops this
form; the symbol table carries `page` regardless. Regression guard for the
`test_hmr_client` pages, which use exactly this shape."""
test "non-pub page inside a cl block is still a route" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/blog.jac",
            "cl {\n    def page() {\n        return <div>post</div>;\n    }\n}\n",
        );
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/blog"} , f"non-pub cl-block page should be a route; got {paths}";
    }
}


"""A layout module registers as a layout (scoped to its dir), never a route."""
test "layout module registers as layout not route" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/layout.jac",
            "def:pub layout() -> JsxElement { return <Outlet />; }",
        );
        _write(
            proj,
            "pages/index.jac",
            "def:pub page() -> JsxElement { return <div>home</div>; }",
        );
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/"} , f"layout must not be a route; got {paths}";
        assert "/" in scanner.get_layouts() , "layout should register under '/'";
    }
}


"""Legacy `.cl.jac` components stay out of the route table via their symbols,
not a suffix rule, so existing projects keep working."""
test "legacy cl-suffixed component stays skipped via symbols" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/budget.jac",
            "def:pub page() -> JsxElement { return <BudgetUI />; }",
        );
        _write(
            proj,
            "pages/budget_ui.cl.jac",
            "def:pub BudgetUI() -> JsxElement { return <div>ui</div>; }",
        );
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/budget"} , f"legacy .cl.jac component should not be a route; got {paths}";
    }
}


"""`.impl.` and `.test.` sidecars are module roles, not routes, and are skipped
structurally without consulting symbols."""
test "impl and test sidecars are not routes" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/budget.jac",
            "def:pub page() -> JsxElement { return <div>b</div>; }",
        );
        _write(proj, "pages/budget.impl.jac", "impl budget.helper { return 1; }");
        _write(proj, "pages/budget.test.jac", "test \"t\" { assert True; }",);
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/budget"} , f"impl/test sidecars must not be routes; got {paths}";
    }
}


"""A page whose symbols cannot be resolved (e.g. a transient compile error) must
stay a route, not silently vanish from the route table; the real compile then
surfaces the error. Fail-safe for the HMR route-refresh path."""
test "unresolvable page stays a route instead of being dropped" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(proj, "pages/blog.jac", "def:pub page() -> JsxElement { return <div",);
        scanner = RouteScanner(proj, symbols_of=_unresolvable);
        paths = _route_paths(scanner);
        assert paths == {"/blog"} , f"unresolvable page must stay a route; got {paths}";
    }
}


"""Dynamic, index, and catch-all route derivation still comes from the filename
once a module qualifies as a route by defining `page`."""
test "dynamic index and catch-all routes still resolve" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        page = "def:pub page() -> JsxElement { return <div/>; }";
        _write(proj, "pages/index.jac", page);
        _write(proj, "pages/users/index.jac", page);
        _write(proj, "pages/users/[id].jac", page);
        _write(proj, "pages/[...notFound].jac", page);
        scanner = RouteScanner(proj, symbols_of=_symbols_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/", "/users", "/users/:id", "/*"} , f"file-derived route paths regressed; got {paths}";
    }
}
