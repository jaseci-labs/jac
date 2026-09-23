"""Dictionary reads recover the declared layout of their tuple values."""
import ctypes;
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    native_str_func
}
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "unpack tuple-valued local global and temporary dictionaries" {
    module = compile_native_ir("dict_tuple_values.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    (engine, _) = compile_native("dict_tuple_values.jac");
    get_func(engine, "jac_entry", None)();
    for (name, expected) in [
        ("global_tuple", 34),
        ("local_tuple", 12),
        ("temporary_tuple", 49)
    ] {
        probe = get_func(engine, name, ctypes.c_int64);
        assert probe() == expected , name;
    }
}

test "unpack an imported tuple-valued dictionary" {
    module = compile_native_ir("dict_tuple_import.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    (engine, _) = compile_native("dict_tuple_import.jac");
    get_func(engine, "jac_entry", None)();
    assert get_func(engine, "imported_tuple", ctypes.c_int64)() == 34;
}

test "subscript tuple values read from dictionaries" {
    (engine, module) = compile_native("dict_tuple_reads.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , str(issues);
    get_func(engine, "jac_entry", None)();
    for (name, expected) in [
        ("int_pair_literal_key", 4),
        ("int_pair_bound", 56),
        ("str_pair_bound", 1),
        ("global_subscript", 297),
        ("get_method", 4),
        ("pop_and_setdefault", 469),
        ("items_loop", 39)
    ] {
        probe = get_func(engine, name, ctypes.c_int64);
        assert probe() == expected , name;
    }
    by_key = native_str_func(
        engine, "str_pair_variable_key", ctypes.c_int64, ctypes.c_char_p
    );
    membership = native_str_func(
        engine, "membership_then_lookup", ctypes.c_int64, ctypes.c_char_p
    );
    three = native_str_func(
        engine, "three_element_values", ctypes.c_int64, ctypes.c_char_p
    );
    nested = native_str_func(
        engine, "nested_subscripts", ctypes.c_int64, ctypes.c_char_p, ctypes.c_char_p
    );
    assert by_key("a") == 32;
    assert by_key("b") == 41;
    assert membership("a2") == 1;
    assert membership("a1") == 2;
    assert membership("b1") == 0;
    assert three("a1") == 321;
    assert three("zz") == -1;
    assert nested("x", "z") == 61;
    assert nested("x", "y") == 31;
}

test "subscripted dictionary tuple reads release their objects once" {
    (engine, _) = compile_native("dict_tuple_reads.jac");
    drops = get_func(engine, "drop_count", ctypes.c_int64);
    probe = native_str_func(engine, "object_elements", ctypes.c_int64, ctypes.c_char_p);
    for _ in range(3) {
        before = drops();
        assert probe("items") == 13;
        assert drops() - before == 2;
    }
}
