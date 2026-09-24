"""Optional results carry ownership through boolean expressions and dictionary reads."""

import ctypes;
import from tests.support { native_address }
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_optional_temporaries(profile: str) {
    program = JacProgram();
    module = program.compile(
        str(Path(__file__).parent / "fixtures" / "rc_optional_temporaries.jac"),
        options=CompileOptions(
            force_codespace="native", force_target_program=True, memory_profile=profile
        )
    );
    assert not program.errors_had , [str(error) for error in program.errors_had];
    engine = module.gen.native_engine;
    assert engine is not None;
    dropped = ctypes.CFUNCTYPE(ctypes.c_int64)(native_address(engine, "dropped_count"));
    for (name, argument, expected, allocations) in [
        ("optional_or", 0, 5, 1),
        ("optional_or", 1, 5, 1),
        ("optional_or", 2, 3, 2),
        ("optional_and", 0, 0, 0),
        ("optional_and", 1, 0, 0),
        ("optional_and", 2, 1, 3),
        ("optional_pair", 0, 2, 2),
        ("optional_pair", 1, 2, 2),
        ("optional_pair", 2, 2, 2),
        ("borrowed_or", 0, 5, 1),
        ("borrowed_or", 1, 5, 1),
        ("borrowed_or", 2, 3, 2),
        ("property_or", 0, 5, 1),
        ("property_or", 1, 5, 1),
        ("property_or", 2, 3, 2),
        ("dict_get", 0, 4, 2),
        ("dict_get", 1, 3, 2),
        ("dict_get_borrowed", 0, 7, 2),
        ("dict_get_borrowed", 1, 6, 2),
        ("dict_optional_get", 0, -1, 1),
        ("dict_optional_get", 1, 3, 1),
        ("dict_stored_none", 0, 9, 1),
        ("dict_stored_none", 1, -1, 1),
        ("dict_stored_zero", 0, -1, 0),
        ("dict_stored_zero", 1, 0, 0),
        ("dict_zero_default", 0, 9, 0),
        ("dict_zero_default", 1, 0, 0),
        ("dict_list_get", 0, 4, 2),
        ("dict_list_get", 1, 3, 2),
        ("dict_string_get", 0, 3, 0),
        ("dict_string_get", 1, 2, 0),
        ("dict_optional_string", 0, -1, 0),
        ("dict_optional_string", 1, 2, 0)
    ] {
        address = native_address(engine, name);
        assert address != 0;
        call = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        before = dropped();
        assert call(argument) == expected , (name, argument);
        assert dropped() - before == allocations , (name, argument);
    }
}

test "optional temporaries preserve values and release references" {
    check_optional_temporaries("rc");
}

test "optional temporaries preserve values with cycle collection" {
    check_optional_temporaries("managed");
}
