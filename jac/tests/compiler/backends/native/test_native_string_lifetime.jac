"""Count live references, independently of RSS and allocator caching."""

import ctypes;
import os;
import from tests.support { TESTS_DIR, get_func }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF }
import from jaclang.compiler.native_compiler { ensure_loaded }

test "native string and temporary roots balance across storage and calls" {
    kernel = ensure_loaded();
    if kernel is None {
        return;
    }
    program = JacProgram();
    options = CompileOptions(
        force_codespace="native",
        force_target_program=True,
        memory_profile="managed",
        no_ir_cache=True
    );
    mod = program.compile(
        os.path.join(
            TESTS_DIR,
            "compiler",
            "backends",
            "native",
            "fixtures",
            "rc_string_lifetime.jac"
        ),
        options=options
    );
    assert not program.errors_had , [str(e) for e in program.errors_had];
    engine = mod.gen.native_engine;
    assert engine is not None;
    make = kernel.lib.jac_str_new;
    release = kernel.lib.jac_release;
    release.argtypes = [ctypes.c_void_p];
    release.restype = None;
    value = b"borrowed";
    references: dict[str, int] = {};
    for (name, copies) in [
        ("local", 1),
        ("field", 1),
        ("loop", 3),
        ("call", 1),
        ("constructor_call", 1),
        ("constructor_list", 1),
        ("sliced", 1),
        ("rebound", 1),
        ("temporary_index", 1),
        ("temporary_condition", 1),
        ("discarded", 1),
        ("compared", 1),
        ("class_call", 1),
        ("view_field", 1),
        ("borrowed_view_field", 1),
        ("compared_view", 1),
        ("mixed_condition", 1),
        ("conditional_owned", 1),
        ("conditional_borrowed", 1),
        ("returned_view", 1),
        ("dict_read", 1),
        ("dict_write", 1),
        ("dict_missing", 1)
    ] {
        buffer_ptr = make(value, len(value));
        fn = get_func(
            engine,
            name,
            ctypes.c_int64,
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_int64
        );
        try {
            assert fn(buffer_ptr, buffer_ptr, len(value)) == copies * len(value);
            references[name] = ctypes.c_int64.from_address(
                buffer_ptr + HDR_RC_OFF
            ).value;
        } finally {
            release(buffer_ptr);
        }
    }
    assert all(count == 1 for count in references.values()) , references;

    make_items = get_func(engine, "empty_items", ctypes.c_void_p);
    destroy_items = get_func(engine, "destroy_items", None, ctypes.c_void_p);
    items_root = make_items();
    assert items_root;
    try {
        assert ctypes.c_int64.from_address(items_root + HDR_RC_OFF).value == 1;
        destroy_items(items_root);
        assert ctypes.c_int64.from_address(items_root + HDR_RC_OFF).value == 1 , (
            "graph deletion retained its temporary target list"
        );
    } finally {
        release(items_root);
    }
}
