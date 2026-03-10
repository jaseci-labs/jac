"""Test reactive state management primitives."""

import from pathlib { Path }
import from jaclang { JacRuntime as Jac }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "reactive signals compile" {
    (module, ) = Jac.jac_import("test_reactive_signals", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that reactive primitives are included
    assert "function createSignal(" in bundle.code;
    assert "function createState(" in bundle.code;
    assert "function createEffect(" in bundle.code;

    # Check that test functions are present
    assert "function test_signal_basic()" in bundle.code;
    assert "function test_signal_with_effect()" in bundle.code;
    assert "function test_state_object()" in bundle.code;
    assert "function test_multiple_signals()" in bundle.code;

    # Check that reactive context is present
    assert "__jacReactiveContext" in bundle.code;

    # Verify closures are working
    assert "signalData.value = newValue" in bundle.code;
}

test "reactive primitives in bundle" {
    (module, ) = Jac.jac_import("test_reactive_signals", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check dependency tracking functions
    assert "function __jacTrackDependency(" in bundle.code;
    assert "function __jacNotifySubscribers(" in bundle.code;
    assert "function __jacScheduleRerender(" in bundle.code;
    assert "function __jacFlushRenders()" in bundle.code;

    # Check that batching is set up
    assert "requestAnimationFrame" in bundle.code;

    # Ensure no syntax errors
    assert "SyntaxError" not in bundle.code;
}
