"""Test closure support in Jac client code."""

import from pathlib { Path }
import from jaclang { JacRuntime as Jac }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "nested function closures" {
    (module, ) = Jac.jac_import("test_closures", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that functions are present
    assert "function make_counter()" in bundle.code;
    assert "function create_signal_simple(" in bundle.code;
    assert "function make_adder(" in bundle.code;
    assert "function create_shared_counter()" in bundle.code;

    # Check that inner functions are present
    assert "function increment()" in bundle.code;
    assert "function getter()" in bundle.code;
    assert "function setter(" in bundle.code;
    assert "function get_value()" in bundle.code;

    # Check that closures can access outer variables
    assert "count" in bundle.code;
    assert "value" in bundle.code;

    # Ensure no import errors
    assert "ImportError" not in bundle.code;
}
