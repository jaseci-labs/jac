"""Test declarative routing system."""

import from pathlib { Path }
import from jaclang { JacRuntime as Jac }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "router compiles" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that router functions are included
    assert "function createRouter(" in bundle.code;
    assert "function Route(" in bundle.code;
    assert "function Link(" in bundle.code;
    assert "function navigate(" in bundle.code;

    # Check that test functions are present
    assert "function test_router_basic()" in bundle.code;
    assert "function test_router_navigation()" in bundle.code;
    assert "function test_router_guards()" in bundle.code;

    # Check route config object
    assert "class RouteConfig" in bundle.code;
}

test "router event listeners" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that event listeners are registered
    assert "popstate" in bundle.code;
    assert "addEventListener" in bundle.code;

    # Check path handling uses pathname
    assert "__jacGetPath" in bundle.code;
    assert "window.location.pathname" in bundle.code;
}

test "router uses reactive signal" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Router should use createSignal for the current path
    assert "createSignal" in bundle.code;
    assert "setCurrentPath" in bundle.code;
}

test "router no hash references" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Hash-based routing should not be present
    assert "hashchange" not in bundle.code;
    assert "window.location.hash" not in bundle.code;
    assert "__jacGetHashPath" not in bundle.code;
}

test "router uses pushstate navigation" {
    (module, ) = Jac.jac_import("test_router", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    assert "pushState" in bundle.code;
    assert "window.history.pushState" in bundle.code;
    assert "PopStateEvent" in bundle.code;
}
