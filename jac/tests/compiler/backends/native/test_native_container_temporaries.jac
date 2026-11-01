"""Native container calls release temporaries while preserving returned elements."""

import ctypes;
import json;
import from tests.support {
    KernelFixture,
    adopt_native_units,
    compile_native_unit,
    native_address,
    remember_native_unit
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""`compile_native` under an explicit memory profile: the kernel compiles the
fixture and its native units are JIT-loaded here; return (engine, fixture)."""
def compile_native_profile(fixture: str, profile: str) -> tuple[any, KernelFixture] {
    options = CompileOptions(force_codespace="native", memory_profile=profile);
    fx = compile_native_unit(fixture, "", options, ["bytecode"]);
    prog = JacProgram();
    prog.options = options;
    adopt_native_units(prog, fx.result, options);
    prog._get_compiler()._load_native_from_cache(
        fx.path, prog, json.loads(fx.unit.interop) if fx.unit.interop else None
    );
    carrier = prog.hub.artifacts.get(fx.path);
    engine = carrier.native_engine if carrier is not None else None;
    assert engine is not None , f"No JIT engine produced for {fixture}";
    remember_native_unit(engine, fx);
    return (engine, fx);
}

def check_containers(profile: str) {
    (engine, _) = compile_native_profile("rc_container_temporaries.jac", profile);
    dropped = ctypes.CFUNCTYPE(ctypes.c_int64)(native_address(engine, "drop_count"));
    for (name, expected, allocations) in [
        ("owned_input", 7, 2),
        ("borrowed_input", 11, 2),
        ("reversed_input", 87, 2),
        ("comprehension_input", 3, 3),
        ("empty_input", 9, 1),
        ("copied_receiver", 10, 1),
        ("popped_receiver", 12, 2),
        ("existing_default", 4, 3),
        ("missing_default", 5, 2),
        ("borrowed_default", 9, 2),
        ("nested_receiver", 8, 1),
        ("property_receiver", 9, 1),
        ("borrowed_field_write", 12, 1),
        ("subscript_receiver", 13, 1),
        ("borrowed_subscript_receiver", 14, 1)
    ] {
        address = native_address(engine, name);
        assert address != 0;
        call = ctypes.CFUNCTYPE(ctypes.c_int64)(address);
        before = dropped();
        assert call() == expected , name;
        assert dropped() - before == allocations , name;
    }
    for (name, index, expected) in [
        ("indexed_receiver", 0, 4),
        ("indexed_receiver", -1, 5),
        ("indexed_receiver", 99, -1),
        ("indexed_receiver", -99, -1),
        ("borrowed_index", 0, 6),
        ("borrowed_index", -1, 7),
        ("borrowed_index", 99, 6),
        ("borrowed_index", -99, 6)
    ] {
        address = native_address(engine, name);
        assert address != 0;
        call = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        before = dropped();
        assert call(index) == expected , (name, index);
        assert dropped() - before == 2 , (name, index);
    }
}

test "container methods free temporaries and preserve borrowed inputs with reference counting" {
    check_containers("rc");
}

test "container methods free temporaries and preserve borrowed inputs with cycle collection" {
    check_containers("managed");
}
