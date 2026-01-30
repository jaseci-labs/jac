"""Test declarative routing system."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac


@pytest.fixture(autouse=True)
def setup_fresh_jac(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Provide fresh Jac context for each test."""
    yield


def test_router_compiles():
    """Test that router system compiles to valid JavaScript."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_router", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check that router functions are included
    assert "function createRouter(" in bundle.code
    assert "function Route(" in bundle.code
    assert "function Link(" in bundle.code
    assert "function navigate(" in bundle.code

    # Check that test functions are present
    assert "function test_router_basic()" in bundle.code
    assert "function test_router_navigation()" in bundle.code
    assert "function test_router_guards()" in bundle.code

    # Check route config object
    assert "class RouteConfig" in bundle.code

    # Print first 3000 chars for debugging
    print("\n=== Router Bundle (first 3000 chars) ===")
    print(bundle.code[:3000])


def test_router_event_listeners():
    """Verify router sets up event listeners."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_router", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check that event listeners are registered (popstate for BrowserRouter-style navigation)
    assert "popstate" in bundle.code
    assert "addEventListener" in bundle.code

    # Check path handling uses pathname (not hash)
    assert "__jacGetPath" in bundle.code
    assert "window.location.pathname" in bundle.code


def test_router_uses_reactive_signal():
    """Verify router uses createSignal for reactive path."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_router", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Router should use createSignal for the current path
    # This makes route changes automatically trigger re-renders
    assert "createSignal" in bundle.code
    assert "setCurrentPath" in bundle.code


def test_router_no_hash_references():
    """Verify router bundle contains no hash-based routing code."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_router", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Hash-based routing should not be present (migrated to BrowserRouter)
    assert "hashchange" not in bundle.code
    assert "window.location.hash" not in bundle.code
    assert "__jacGetHashPath" not in bundle.code


def test_router_uses_pushstate_navigation():
    """Verify router uses pushState for client-side navigation."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_router", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    assert "pushState" in bundle.code
    assert "window.history.pushState" in bundle.code
    assert "PopStateEvent" in bundle.code
