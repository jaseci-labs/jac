"""Count live references, independently of RSS and allocator caching."""

import ctypes;
import json;
import from tests.support {
    KernelFixture,
    adopt_native_units,
    compile_native_unit,
    get_func,
    native_address,
    remember_native_unit
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF }

"""`compile_native` under the cycle collector: the kernel compiles the fixture
and its native units are JIT-loaded here; return (engine, fixture)."""
def compile_native_managed(fixture: str) -> tuple[any, KernelFixture] {
    options = CompileOptions(
        force_codespace="native", memory_profile="managed", no_ir_cache=True
    );
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

test "native string and temporary roots balance across storage and calls" {
    (engine, _) = compile_native_managed("rc_string_lifetime.jac");
    make = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(
        native_address(engine, "jac_str_new")
    );
    release = ctypes.CFUNCTYPE(None, ctypes.c_void_p)(
        native_address(engine, "jac_release")
    );
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
