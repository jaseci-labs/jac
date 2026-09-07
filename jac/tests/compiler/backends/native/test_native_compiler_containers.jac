"""Execute compiler container contracts, rejecting demotion before invocation."""
import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.backends.native.lowering { native_lowering_issues }

test "compiler tuple containers retain values across native operations" {
    (engine, module) = compile_native("compiler_tuple_containers.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    guard = get_func(engine, "protocol_guard", ctypes.c_int64);
    kinds = get_func(engine, "runtime_base_kinds", ctypes.c_int64);
    interval = get_func(engine, "read_interval", ctypes.c_int64, ctypes.c_int64);
    assert guard() == 21;
    assert kinds() == 4121;
    assert interval(0) == -1;
    assert interval(1) == 37;
    intern_keys = get_func(engine, "canonical_intern_keys", ctypes.c_int64);
    assert intern_keys() == 15;
    zero_key = get_func(engine, "signed_zero_key", ctypes.c_int64);
    assert zero_key() == 1;
}

test "optional empty constructors keep their declared element types" {
    (engine, module) = compile_native("optional_empty_containers.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    make_set = get_func(engine, "optional_set", ctypes.c_int64, ctypes.c_int64);
    make_list = get_func(engine, "optional_list", ctypes.c_int64);
    assert make_set(0) == 2;
    assert make_set(1) == 2;
    assert make_list() == 7;
}

test "dictionary comprehensions preserve key types and iteration order" {
    (engine, module) = compile_native("dictionary_comprehensions.jac");
    issues = native_lowering_issues(str(module.gen.llvm_ir));
    assert not issues , "\n".join(issue.detail for issue in issues);
    selected = get_func(engine, "dictionary_comprehensions", ctypes.c_int64);
    empty = get_func(engine, "empty_dictionary_comprehensions", ctypes.c_int64);
    assert selected() == 23;
    assert empty() == 0;
    object_items = get_func(engine, "object_items_comprehension", ctypes.c_int64);
    drops = get_func(engine, "item_drop_count", ctypes.c_int64);
    before = drops();
    assert object_items() == 223;
    assert drops() - before == 2;
    scope = get_func(engine, "comprehension_scope", ctypes.c_int64, ctypes.c_int64);
    before = drops();
    scope_value = scope(7);
    assert scope_value == 125 , scope_value;
    assert drops() - before == 3;
    stored = get_func(engine, "stored_items_lifetime", ctypes.c_int64);
    before = drops();
    assert stored() == 9;
    assert drops() - before == 2;
    set_items = get_func(engine, "set_items_lifetime", ctypes.c_int64);
    before = drops();
    assert set_items() == 2;
    assert drops() - before == 2;
}
