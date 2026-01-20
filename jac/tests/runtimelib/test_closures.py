"""Test closure support in Jac client code."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac


@pytest.fixture(autouse=True)
def setup_fresh_jac(fresh_jac_context: Path) -> Generator[None, None, None]:
    """Provide fresh Jac context for each test."""
    yield


def test_nested_function_closures():
    """Test that nested functions can access outer scope variables."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    (module,) = Jac.jac_import("test_closures", str(fixtures_dir))

    builder = Jac.get_client_bundle_builder()
    bundle = builder.build(module)

    # Print the generated JavaScript for debugging
    print("\\n=== Generated JavaScript ===")
    print(bundle.code[:2000])  # Print first 2000 chars
    print("\\n=== Test Functions ===")

    # Check that functions are present
    assert "function make_counter()" in bundle.code
    assert "function create_signal_simple(" in bundle.code
    assert "function make_adder(" in bundle.code
    assert "function create_shared_counter()" in bundle.code

    # Check that inner functions are present
    assert "function increment()" in bundle.code
    assert "function getter()" in bundle.code
    assert "function setter(" in bundle.code
    assert "function get_value()" in bundle.code

    # Check that closures can access outer variables
    # The generated code should contain references to 'count' and 'value'
    assert "count" in bundle.code
    assert "value" in bundle.code

    # Ensure no import errors
    assert "ImportError" not in bundle.code
