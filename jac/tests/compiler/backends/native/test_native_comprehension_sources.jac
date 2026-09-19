"""Native comprehensions iterate every source a native for-loop iterates."""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

test "comprehensions over ranges, strings, bytes, sets and adapters run natively" {
    program = JacProgram();
    module = program.compile(
        os.path.join(
            TESTS_DIR,
            "compiler",
            "backends",
            "native",
            "fixtures",
            "comprehension_sources.jac"
        ),
        options=CompileOptions(
            force_codespace="native",
            force_target_program=True,
            need_full_ast=True,
            no_ir_cache=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
    engine = module.gen.native_engine;
    assert engine is not None;
    expected = [
        ("stepped", 307),
        ("descending", 302),
        ("over_str", 31),
        ("over_glob_literal", 31),
        ("over_bytes", 306),
        ("over_set", 222),
        ("short_circuit", 104),
        ("enumerated", 135)
    ];
    for (name, want) in expected {
        address = engine.get_function_address(name);
        assert isinstance(address, int) and address != 0 , name;
        got = ctypes.CFUNCTYPE(ctypes.c_int64)(address)();
        assert got == want , f"{name}: {got} != {want}";
    }
}
