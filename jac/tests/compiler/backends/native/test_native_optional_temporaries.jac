"""Optional results carry ownership through boolean expressions and dictionary reads."""

import ctypes;
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
    dropped = ctypes.CFUNCTYPE(ctypes.c_int64)(
        engine.get_function_address("dropped_count")
    );
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
        ("dict_list_get", 0, 4, 2),
        ("dict_list_get", 1, 3, 2),
        ("dict_string_get", 0, 3, 0),
        ("dict_string_get", 1, 2, 0),
        ("dict_optional_string", 0, -1, 0),
        ("dict_optional_string", 1, 2, 0),
        ("none_predicates", 0, 4, 0),
        ("none_predicates", 1, 4, 0),
        ("none_predicates", 2, 4, 16),
        ("predicate_branch", 0, -1, 0),
        ("predicate_branch", 1, 0, 0),
        ("predicate_branch", 2, 2, 2),
        ("predicate_chain", 0, 0, 0),
        ("predicate_chain", 1, 1, 0),
        ("predicate_chain", 2, 1, 4),
        ("type_predicate", 0, 0, 0),
        ("type_predicate", 1, 1, 0),
        ("type_predicate", 2, 1, 2),
        ("borrowed_predicates", 0, -1, 0),
        ("borrowed_predicates", 1, 0, 0),
        ("borrowed_predicates", 2, 2, 2),
        ("predicate_binding", 0, -1, 0),
        ("predicate_binding", 1, 0, 0),
        ("predicate_binding", 2, 2, 2),
        ("predicate_loop", 0, 0, 0),
        ("predicate_loop", 1, 0, 0),
        ("predicate_loop", 2, 8, 8),
        ("catch_predicate_unwind", 0, 0, 0),
        ("catch_predicate_unwind", 2, 2, 2),
        ("catch_predicate_operand", 0, 0, 0),
        ("catch_predicate_operand", 2, 2, 2),
        ("catch_inside_owned_loop", 0, 7, 2),
        ("catch_inside_owned_loop", 2, 7, 6),
        ("dynamic_none", 0, 1, 0),
        ("dynamic_none", 1, 1, 0),
        ("dynamic_none", 2, 1, 1),
        ("dynamic_type", 0, 0, 0),
        ("dynamic_type", 1, 0, 0),
        ("dynamic_type", 2, 1, 1),
        ("membership_temporaries", 2, 2, 3)
    ] {
        address = engine.get_function_address(name);
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
