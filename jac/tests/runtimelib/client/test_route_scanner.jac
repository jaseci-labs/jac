"""Route-scanner membership tests for the file-based router.

Route membership is a TYPE, not a name: a `pages/` module is a route when a
public export returns the ambient `JsxPage` type, and a layout when one returns
`JsxLayout`. The export's name is free (`Dashboard`, `Shell`, ...), and the router
imports it by that name. A co-located component returns `JsxElement`, so it is
never a route and needs no marker.

The URL still comes from the filename (`index.jac` -> the directory root,
`[id].jac` -> `:id`, `[...rest].jac` -> catch-all).

The scanner takes an injected `route_exports_of` resolver returning
`(page_export, layout_export)`; in production it is backed by the compiled
module's client manifest. Here it reads the written source, standing in for
`manifest.page_export` / `manifest.layout_export`.
"""

import re;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.runtimelib.client.route_scanner {
    RouteScanner,
    describe_pages_without_routes
}


"""Write `body` to `base/rel`, creating parent directories."""
def _write(base: Path, rel: str, body: str) -> Path {
    target = base / rel;
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(body, encoding='utf-8');
    return target;
}


"""Stand-in for the compiled manifest's `page_export` / `layout_export`.

Reports the name of the export annotated `-> JsxPage` and the one annotated
`-> JsxLayout`, mirroring what the codegen records from the return type.
"""
def _route_exports_from_source(path: Path) -> tuple[((str | None), (str | None))] {
    try {
        text = path.read_text(encoding='utf-8');
    } except OSError {
        return (None, None);
    }
    page_hit = re.search(r'def(?::\w+)?\s+(\w+)\s*\([^)]*\)\s*->\s*JsxPage\b', text);
    layout_hit = re.search(
        r'def(?::\w+)?\s+(\w+)\s*\([^)]*\)\s*->\s*JsxLayout\b', text
    );
    return (
        page_hit.group(1) if page_hit else None,
        layout_hit.group(1) if layout_hit else None,

    );
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


"""A `-> JsxPage` export makes the file a route under any export name, and the
scanner records that name so the generated manifest can import it."""
test "page is marked by the Page return type under a free export name" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/dashboard.jac",
            "def:pub Dashboard() -> JsxPage { return <div>d</div>; }",
        );
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        routes = scanner.scan();
        paths = {r.path for r in routes};
        assert paths == {"/dashboard"} , f"Page-typed export should be a route; got {paths}";
        assert routes[0].source_export == "Dashboard" , (
            f"scanner must record the real export name; got {routes[0].source_export}"
        );
    }
}


"""A co-located component returns JsxElement, not Page, so it is not a route -
no marker, no filename convention needed."""
test "co-located JsxElement component is not a route" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/budget.jac",
            "def:pub Budget() -> JsxPage { return <BudgetUI />; }",
        );
        _write(
            proj,
            "pages/budget_ui.jac",
            "def:pub BudgetUI() -> JsxElement { return <div>ui</div>; }",
        );
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/budget"} , f"JsxElement component must not be a route; got {paths}";
    }
}


"""A `-> JsxLayout` export makes the file its directory's layout under any name and
any filename - `layout.jac` is no longer required."""
test "layout is marked by the Layout return type under a free filename" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/shell.jac",
            "def:pub Shell() -> JsxLayout { return <div><Outlet /></div>; }",
        );
        _write(
            proj,
            "pages/index.jac",
            "def:pub Home() -> JsxPage { return <div>home</div>; }",
        );
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/"} , f"layout must not be a route; got {paths}";
        layouts = scanner.get_layouts();
        assert "/" in layouts , "Layout-typed export should register under '/'";
        assert layouts["/"].source_export == "Shell" , (
            f"layout must record its export name; got {layouts['/'].source_export}"
        );
    }
}


"""The reserved names no longer mark anything: a module defining `page` /
`layout` that does NOT return Page/Layout is just a component."""
test "page and layout names alone no longer make a route" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/index.jac",
            "def:pub Home() -> JsxPage { return <div>home</div>; }",
        );
        _write(
            proj,
            "pages/legacy.jac",
            "def:pub page() -> JsxElement { return <div>old</div>; }",
        );
        _write(
            proj,
            "pages/layout.jac",
            "def:pub layout() -> JsxElement { return <Outlet />; }",
        );
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/"} , f"untyped page/layout names must not route; got {paths}";
        assert not scanner.get_layouts() , "untyped layout.jac must not register a layout";
    }
}


"""`.impl.` and `.test.` sidecars are module roles, never routes."""
test "impl and test sidecars are not routes" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/budget.jac",
            "def:pub Budget() -> JsxPage { return <div>b</div>; }",
        );
        _write(proj, "pages/budget.impl.jac", "impl budget.helper { return 1; }");
        _write(proj, "pages/budget.test.jac", "test \"t\" { assert True; }");
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/budget"} , f"sidecars must not be routes; got {paths}";
    }
}


"""URL derivation still comes from the filename once a module qualifies as a
route by its Page return type."""
test "dynamic index and catch-all urls still derive from the filename" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        page = "def:pub View() -> JsxPage { return <div/>; }";
        _write(proj, "pages/index.jac", page);
        _write(proj, "pages/users/index.jac", page);
        _write(proj, "pages/users/[id].jac", page);
        _write(proj, "pages/[...notFound].jac", page);
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        paths = _route_paths(scanner);
        assert paths == {"/", "/users", "/users/:id", "/*"} , (
            f"file-derived route paths regressed; got {paths}"
        );
    }
}


"""A page and a layout whose paths sanitize to the same JS identifier are a
build error - caught across routes and layouts, keyed on the return type."""
test "a page and a layout that sanitize to the same identifier raise ClientBundleError" {
    import from jaclang.runtimelib.client_bundle { ClientBundleError }
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/admin-layout.jac",
            "def:pub View() -> JsxPage { return <div>admin</div>; }",
        );
        _write(
            proj,
            "pages/admin/layout.jac",
            "def:pub Shell() -> JsxLayout { return <Outlet />; }",
        );
        scanner = RouteScanner(proj, route_exports_of=_route_exports_from_source);
        raised = False;
        try {
            scanner.scan();
        } except ClientBundleError as err {
            raised = True;
            assert "PagesAdminLayout" in str(err);
        }
        assert raised , "expected a ClientBundleError on page/layout identifier collision";
    }
}


"""A pages/ tree with modules but zero recognized routes is a silent blank
page unless the compiler says something. The diagnostic names the outcome,
the rule, and every file that looks like the retired name-based convention
(a route-named export returning JsxElement instead of JsxPage/JsxLayout)."""
test "zero-route pages tree yields a diagnostic with a legacy hint" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj,
            "pages/index.jac",
            "def:pub page() -> JsxElement { return <div>old</div>; }",
        );
        _write(
            proj,
            "pages/layout.jac",
            "def:pub layout() -> JsxElement { return <Outlet />; }",
        );
        lines = describe_pages_without_routes(proj / "pages");
        assert lines , "zero routes must not be silent";
        joined = "\n".join(lines);
        assert "blank page" in joined , "headline must say what the user will see";
        assert "JsxPage" in joined , "hint must name the page fix";
        assert "JsxLayout" in joined , "hint must name the layout fix";
        assert "index.jac" in joined , "hint must name the offending page file";
        assert "layout.jac" in joined , "hint must name the offending layout file";
    }
}


"""No candidates, no noise: an empty pages/ tree stays quiet."""
test "empty pages tree yields no diagnostic" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / "pages").mkdir(parents=True);
        assert describe_pages_without_routes(proj / "pages") == [];
    }
}


"""Sidecar annexes are module roles, not route candidates, so they neither
trigger the headline nor appear in the hints."""
test "sidecar annexes do not trigger the zero-route diagnostic" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(
            proj, "pages/budget.impl.jac", "impl budget.view { return <div>x</div>; }",
        );
        _write(proj, "pages/budget.test.jac", "test \"t\" { assert True; }");
        assert describe_pages_without_routes(proj / "pages") == [];
    }
}


"""Modules that are not legacy-shaped still get the headline (the tree has
candidates and no routes) without per-file hints."""
test "non-legacy zero-route tree gets the headline only" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _write(proj, "pages/util.jac", "def helper() -> int { return 1; }",);
        lines = describe_pages_without_routes(proj / "pages");
        assert lines , "candidate modules with zero routes must warn";
        joined = "\n".join(lines);
        assert "blank page" in joined;
        assert "util.jac" not in joined , "non-legacy modules are not called out";
    }
}
