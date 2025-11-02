"""Test declarative routing system."""

from __future__ import annotations
from pathlib import Path

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase


class RouterTests(TestCase):
    """Test declarative routing."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def test_router_compiles(self) -> None:
        """Test that router system compiles to valid JavaScript."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_router", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check that router functions are included
        self.assertIn("function createRouter(", bundle.code)
        self.assertIn("function Route(", bundle.code)
        self.assertIn("function Link(", bundle.code)
        self.assertIn("function navigate(", bundle.code)

        # Check that test functions are present
        self.assertIn("function test_router_basic()", bundle.code)
        self.assertIn("function test_router_navigation()", bundle.code)
        self.assertIn("function test_router_guards()", bundle.code)

        # Check route config object
        self.assertIn("class RouteConfig", bundle.code)

        # Print first 3000 chars for debugging
        print("\n=== Router Bundle (first 3000 chars) ===")
        print(bundle.code[:3000])

    def test_router_event_listeners(self) -> None:
        """Verify router sets up event listeners."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_router", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check that event listeners are registered
        self.assertIn("hashchange", bundle.code)
        self.assertIn("popstate", bundle.code)
        self.assertIn("addEventListener", bundle.code)

        # Check hash path handling
        self.assertIn("__jacGetHashPath", bundle.code)
        self.assertIn("window.location.hash", bundle.code)

    def test_router_uses_reactive_signal(self) -> None:
        """Verify router uses createSignal for reactive path."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_router", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Router should use createSignal for the current path
        # This makes route changes automatically trigger re-renders
        self.assertIn("createSignal", bundle.code)
        self.assertIn("setCurrentPath", bundle.code)
