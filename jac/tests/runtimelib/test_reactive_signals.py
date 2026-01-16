"""Test reactive state management primitives."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac


@pytest.fixture(autouse=True)
def setup_fresh_jac(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Provide fresh Jac context for each test."""
    yield


def test_reactive_signals_compile():
    """Test that reactive signals compile to valid JavaScript."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_reactive_signals", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check that reactive primitives are included
    assert "function createSignal(" in bundle.code
    assert "function createState(" in bundle.code
    assert "function createEffect(" in bundle.code

    # Check that test functions are present
    assert "function test_signal_basic()" in bundle.code
    assert "function test_signal_with_effect()" in bundle.code
    assert "function test_state_object()" in bundle.code
    assert "function test_multiple_signals()" in bundle.code

    # Check that reactive context is present
    assert "__jacReactiveContext" in bundle.code

    # Verify closures are working (no 'let' redeclarations in nested functions)
    # The setter should access the outer signalData, not redeclare it
    assert "signalData.value = newValue" in bundle.code

    # Print first 3000 chars for debugging
    print("\n=== Reactive Signals Bundle (first 3000 chars) ===")
    print(bundle.code[:3000])


def test_reactive_primitives_in_bundle():
    """Verify all reactive primitives are exported."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_reactive_signals", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Check dependency tracking functions
    assert "function __jacTrackDependency(" in bundle.code
    assert "function __jacNotifySubscribers(" in bundle.code
    assert "function __jacScheduleRerender(" in bundle.code
    assert "function __jacFlushRenders()" in bundle.code

    # Check that batching is set up
    assert "requestAnimationFrame" in bundle.code

    # Ensure no syntax errors
    assert "SyntaxError" not in bundle.code
