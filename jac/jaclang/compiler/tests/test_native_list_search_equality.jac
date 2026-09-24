import ctypes;
import from jaclang.compiler.tests.xbackend_equiv { compile_native, get_func }

test "native list searches use value equality and valid comparison loop edges" {
    (engine, ir) = compile_native("native_list_search_equality.jac", no_ir_cache=True);
    for name in [
        "search_strings",
        "search_floats",
        "search_bytes",
        "search_lists",
        "search_missing"
    ] {
        function = get_func(engine, name, ctypes.c_int64);
        assert function() == 1 , name;
    }
}
