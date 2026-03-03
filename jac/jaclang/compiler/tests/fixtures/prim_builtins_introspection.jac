"""BuiltinEmitter introspection methods.

Tests emit_enumerate, emit_zip, emit_map, emit_filter,
emit_isinstance, emit_issubclass, emit_type, emit_repr, emit_ascii,
emit_callable, emit_hash, emit_id, emit_iter, emit_next,
emit_hasattr, emit_getattr, emit_setattr, emit_vars, emit_delattr,
emit_dir, emit_print, emit_input, emit_open.

Python/SV only — CL and NA return {} (not yet implemented).
"""

class _I {
    has x: int = 0;
}

def builtins_introspection_py() -> dict {
    # emit_enumerate
    enum_pairs: list = list(enumerate(["a", "b", "c"]));

    # emit_zip
    zip_pairs: list = list(zip([1, 2, 3], ["a", "b", "c"]));

    # emit_map
    map_result: list = list(map(str, [1, 2, 3]));

    # emit_filter
    filter_result: list = list(filter(None, [0, 1, 0, 2, 0, 3]));

    # emit_setattr / emit_getattr / emit_hasattr / emit_vars / emit_delattr
    o: _I = _I();
    setattr(o, "x", 99);
    setattr_ok: int = 1 if o.x == 99 else 0;
    vars_ok: int = 1 if isinstance(vars(o), dict) else 0;
    setattr(o, "_d", "tmp");
    has_dyn: int = 1 if hasattr(o, "_d") else 0;
    delattr(o, "_d");
    del_ok: int = 0 if hasattr(o, "_d") else 1;

    return {
        # emit_enumerate
        "enumerate_len": len(enum_pairs),
        "enumerate_0_idx": enum_pairs[0][0],
        "enumerate_2_val": enum_pairs[2][1],
        # emit_zip
        "zip_len": len(zip_pairs),
        "zip_0_a": zip_pairs[0][0],
        # emit_map
        "map_result": map_result,
        # emit_filter
        "filter_result": filter_result,
        # emit_isinstance
        "isinstance_int_t": 1 if isinstance(42, int) else 0,
        "isinstance_int_f": 1 if isinstance(42, str) else 0,
        "isinstance_exc": 1 if isinstance(ValueError("x"), Exception) else 0,
        # emit_issubclass
        "issubclass_val_exc": 1 if issubclass(ValueError, Exception) else 0,
        "issubclass_idx_lookup": 1 if issubclass(IndexError, LookupError) else 0,
        "issubclass_int_str": 1 if issubclass(int, str) else 0,
        # emit_type
        "type_int": type(42).__name__,
        "type_str": type("hi").__name__,
        "type_list": type([]).__name__,
        # emit_repr
        "repr_42": repr(42),
        "repr_neg5": repr(-5),
        # emit_ascii
        "ascii_hello": ascii("hello"),
        # emit_callable
        "callable_fn": 1 if callable(len) else 0,
        "callable_int": 1 if callable(42) else 0,
        # emit_hash (CPython: hash(n) == n for small integers)
        "hash_42": hash(42),
        "hash_0": hash(0),
        # emit_id (any object has a positive id)
        "id_positive": 1 if id(42) > 0 else 0,
        # emit_iter / emit_next
        "iter_next_10": next(iter([10, 20, 30])),
        "iter_next_99": next(iter([99])),
        # emit_hasattr / emit_getattr
        "hasattr_t": 1 if hasattr([], "append") else 0,
        "hasattr_f": 1 if hasattr([], "_missing_xxx") else 0,
        "getattr_ok": getattr("hello", "upper")(),
        # emit_setattr / emit_vars
        "setattr_ok": setattr_ok,
        "vars_ok": vars_ok,
        # emit_delattr
        "has_dyn": has_dyn,
        "del_ok": del_ok,
        # emit_dir
        "dir_ok": 1 if "append" in dir([]) else 0,
        # emit_print (callable check — avoids stdout noise)
        "callable_print": 1 if callable(print) else 0,
        # emit_input
        "callable_input": 1 if callable(input) else 0,
        # emit_open
        "callable_open": 1 if callable(open) else 0,
    };
}

cl def builtins_introspection_cl() -> dict {
    return {};
}

na {
    def builtins_introspection_na() -> dict[str, any] {
        return {};
    }
}
