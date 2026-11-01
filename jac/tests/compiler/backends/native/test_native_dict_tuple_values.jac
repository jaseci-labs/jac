"""Dictionary reads recover the declared layout of their tuple values."""
import ctypes;
import from tests.support { compile_mir, compile_native, get_func, native_str_func }

test "unpack tuple-valued local global and temporary dictionaries" {
    demoted = compile_mir("dict_tuple_values.jac").demoted();
    assert not demoted , str(demoted);
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
    demoted = compile_mir("dict_tuple_import.jac").demoted();
    assert not demoted , str(demoted);
    (engine, _) = compile_native("dict_tuple_import.jac");
    get_func(engine, "jac_entry", None)();
    assert get_func(engine, "imported_tuple", ctypes.c_int64)() == 34;
}

test "setdefault and get keep a key's boxed tuple alive" {
    demoted = compile_mir("dict_nested_tuple_keys.jac").demoted();
    assert not demoted , str(demoted);
    (engine, _) = compile_native("dict_nested_tuple_keys.jac");
    assert get_func(engine, "setdefault_nested_keys", ctypes.c_int64)() == 121;
    assert get_func(engine, "get_nested_keys", ctypes.c_int64)() == 1;
}

test "subscript tuple values read from dictionaries" {
    demoted = compile_mir("dict_tuple_reads.jac").demoted();
    assert not demoted , str(demoted);
    (engine, _) = compile_native("dict_tuple_reads.jac");
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
