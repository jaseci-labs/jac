"""flow for else must survive the parallel-eligible memory profile (#8629).

`_try_flow_for_parallel` outlines the body into worker/join CFGs and
has no else machinery, so an else-bearing `flow for` bails to the
sequential lowerings. Under `--memory rc` the parallel path engages
(default managed never reaches it), which is exactly where the else
suite used to be swallowed silently: the probes below return False
when the parallel path consumes an else-bearing loop again."""

import os;
import ctypes;
import from tests.support { KernelFixture, NATIVE_FIXTURES, compile_native, get_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(NATIVE_FIXTURES, "flow_for_else_run.jac"),
     PROBES = [("flow_else_exhausts", True), ("flow_else_zero_iter", True)];

"""`compile_native` under explicit options: kernel compile, then JIT the
unit in this process."""
def compile_native_with(
    fixture: str, options: CompileOptions, fixture_dir: str = ""
) -> tuple[any, KernelFixture] {
    return compile_native(fixture, fixture_dir, options);
}

def compile_with_profile(memory: str) -> tuple[any, KernelFixture] {
    return compile_native_with(
        FIXTURE, CompileOptions(force_codespace="native", memory_profile=memory)
    );
}

test "flow for else runs in the parallel-eligible rc profile" {
    (eng, _ir) = compile_with_profile("rc");
    for (name, want) in PROBES {
        f = get_func(eng, name, ctypes.c_bool);
        got = f();
        assert got is want , (
            f"{name}: rc profile returned {got} -- the parallel path "
            f"swallowed the else suite"
        );
    }
}

test "flow for else agrees in the sequential managed profile" {
    (eng, _ir) = compile_with_profile("managed");
    for (name, want) in PROBES {
        f = get_func(eng, name, ctypes.c_bool);
        got = f();
        assert got is want , f"{name}: managed profile lost the else suite";
    }
}
