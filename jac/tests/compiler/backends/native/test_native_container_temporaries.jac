"""Native container calls release temporaries while preserving returned elements."""

import ctypes;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.na_constants {
    LIVE_NODE_ID_OFF,
    LIVE_NODE_TAG_OFF,
    LIVE_NODE_NEXT_OFF
}

def live_allocations(address: int) -> dict[int, str] {
    nodes: dict[int, str] = {};
    visited: set[int] = set();
    current = int(ctypes.c_void_p.from_address(address).value or 0);
    while current {
        assert current not in visited , "native live-allocation list contains a cycle";
        visited.add(current);
        identity = int(ctypes.c_uint64.from_address(current + LIVE_NODE_ID_OFF).value);
        nodes[identity] = str(
            ctypes.c_char_p.from_address(current + LIVE_NODE_TAG_OFF).value
        );
        current = int(
            ctypes.c_void_p.from_address(current + LIVE_NODE_NEXT_OFF).value or 0
        );
    }
    return nodes;
}

def check_containers(profile: str) {
    program = JacProgram();
    module = program.compile(
        str(Path(__file__).parent / "fixtures" / "rc_container_temporaries.jac"),
        options=CompileOptions(
            force_codespace="native",
            force_target_program=True,
            memory_profile=profile,
            rc_debug_codegen=True
        )
    );
    assert not program.errors_had , [str(error) for error in program.errors_had];
    engine = module.gen.native_engine;
    assert engine is not None;
    live_address = int(engine.get_global_value_address("__rc_live_head"));
    assert live_address != 0;
    dropped = ctypes.CFUNCTYPE(ctypes.c_int64)(
        engine.get_function_address("drop_count")
    );
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
        ("join_generator", 1, 1),
        ("join_comprehension", 1, 1),
        ("list_generator", 3, 1),
        ("string_receiver_evaluations", 1, 0),
        ("bytes_receiver", 1, 0),
        ("chained_string_receiver", 1, 0),
        ("borrowed_string_receiver", 1, 0),
        ("empty_retyped_loop", 6, 1),
        ("populated_retyped_loop", 10, 1),
        ("skipped_retyped_loop", 6, 1),
        ("repeated_retyped_loop", 3, 3),
        ("scalar_retyped_loop", 3, 1),
        ("redeclared_local", 7, 2),
        ("borrowed_retyped_parameter", 11, 1),
        ("owned_optional_field", 3, 1),
        ("borrowed_optional_field", 4, 1),
        ("aliased_optional_field", 5, 1),
        ("overwritten_optional_field", 7, 2),
        ("borrowed_substring_lookup", 21, 0),
        ("borrowed_substring_receiver", 1, 0),
        ("owned_substring_prefix", 1, 0),
        ("owned_substring_suffix", 1, 0),
        ("escaped_substring_container", 1, 0),
        ("compared_substring_loop", 3, 0),
        ("returned_boxed_substring", 1, 0),
        ("substring_builtin_identity", 1, 0),
        ("boxed_substring_container", 1, 0),
        ("boxed_local_overwrite", 3, 2),
        ("boxed_borrowed_local", 4, 1),
        ("boxed_loop_local", 3, 3),
        ("returned_boxed_local", 6, 1),
        ("boxed_loop_binding", 1, 2),
        ("boxed_comprehension_binding", 1, 2),
        ("boxed_match_binding", 1, 1),
        ("boxed_tuple_binding", 1, 2),
        ("boxed_parameter_binding", 1, 2),
        ("boxed_walrus_binding", 1, 1),
        ("boxed_dict_binding", 4, 2),
        ("boxed_tuple_escape", 3, 1),
        ("boxed_tuple_swap", 3, 2),
        ("boxed_walrus_parameter_binding", 3, 2),
        ("boxed_nested_parameter_binding", 2, 2),
        ("returned_substring_tuple", 1, 0),
        ("returned_aliased_local_tuple", 15, 1),
        ("returned_boxed_local_tuple", 3, 1),
        ("narrowed_union_binding", 1, 0),
        ("explicit_cast_binding", 5, 0)
    ] {
        address = engine.get_function_address(name);
        assert address != 0;
        call = ctypes.CFUNCTYPE(ctypes.c_int64)(address);
        before = dropped();
        before_live = live_allocations(live_address);
        result = call();
        assert result == expected , (name, result, expected);
        assert dropped() - before == allocations , name;
        assert live_allocations(live_address) == before_live , (
            name,
            before_live,
            live_allocations(live_address)
        );
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
        address = engine.get_function_address(name);
        assert address != 0;
        call = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
        before = dropped();
        before_live = live_allocations(live_address);
        assert call(index) == expected , (name, index);
        assert dropped() - before == 2 , (name, index);
        assert live_allocations(live_address) == before_live , (
            name,
            index,
            before_live,
            live_allocations(live_address)
        );
    }
}

test "container methods free temporaries and preserve borrowed inputs with reference counting" {
    check_containers("rc");
}

test "container methods free temporaries and preserve borrowed inputs with cycle collection" {
    check_containers("managed");
}
