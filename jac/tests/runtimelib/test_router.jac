"""Test declarative routing system.

Bare-serve and jac-client expose the same React Router v6-shaped surface.
These tests exercise bare-serve's bundle (jac-client's plugin override is
inactive in pytest), verifying that the new routing primitives — `Routes`,
`Route`, `Link`, `Navigate`, `Outlet`, `useNavigate` / `useLocation` /
`useParams` — flow through codegen with the popstate-driven URL signal
underneath.
"""

import from pathlib { Path }
import from jaclang { JacRuntime as Jac }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "router compiles" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # React Router v6-shaped routing primitives.
    assert "function Router(" in bundle.code;
    assert "function Routes(" in bundle.code;
    assert "function Route(" in bundle.code;
    assert "function Link(" in bundle.code;
    assert "function Navigate(" in bundle.code;
    assert "function Outlet" in bundle.code;
    assert "function navigate(" in bundle.code;
    assert "function useNavigate" in bundle.code;
    assert "function useLocation" in bundle.code;
    assert "function useParams" in bundle.code;

    # Fixture's test functions are present in the bundle.
    assert "function test_router_basic" in bundle.code;
    assert "function test_router_navigation" in bundle.code;
    assert "function test_router_guards" in bundle.code;
}

test "router event listeners" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # popstate listener is wired in `_ensureRouter` so back/forward buttons
    # update the path signal.
    assert "popstate" in bundle.code;
    assert "addEventListener" in bundle.code;

    # Path source is window.location.pathname (no hash routing).
    assert "__jacGetPath" in bundle.code;
    assert "window.location.pathname" in bundle.code;
}

test "router uses reactive signal" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Router's path is a reactive signal — `_ensureRouter` calls createSignal
    # and exposes the setter as `setPath`.
    assert "createSignal" in bundle.code;
    assert "setPath" in bundle.code;
}

test "router no hash references" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Hash-based ROUTING should not be present — bare-serve uses pathname
    # via popstate, not hashchange. (`useLocation` does expose
    # `location.hash` as a value the way React Router does, so we don't
    # forbid the substring outright; we forbid the routing wiring.)
    assert "hashchange" not in bundle.code;
    assert "__jacGetHashPath" not in bundle.code;
}

test "router uses pushstate navigation" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # `navigate(path)` pushes to History API and updates the signal.
    assert "pushState" in bundle.code;
    assert "window.history.pushState" in bundle.code;
}
