"""End-to-end tests for the native iterator protocol (#6403).

Covers lazy adapters (map/filter/enumerate/zip) driven through for-loops,
composition, break/empty edge cases, and first-class iter()/next() values.

Each fixture is compiled once and its functions are checked as one table.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "iter_adapters: map, filter, enumerate and zip drive for-loops" {
    (eng, _) = compile_native("iter_adapters.jac");
    want = {
        "map_sum": 20,
        "filter_sum": 12,
        "filter_empty": 0,
        "compose_sum": 24,  # map over filter
        "map_break": 6,
        "enum_sum": 360,  # enumerate / zip unpack tuples
        "zip_sum": 140,
        "zip_unequal": 50
    };
    got = {fn: get_func(eng, fn, ctypes.c_int64)() for fn in want};
    assert got == want , {
        fn: (got[fn], want[fn])
        for fn in want
        if got[fn] != want[fn]
    };
}

test "iter_protocol: first-class iter() and next() over every iterable" {
    (eng, _) = compile_native("iter_protocol.jac");
    want = {
        "iterator_list_values": 25,
        # iter() / next() over a stored iterator
        "iter_next_basic": 57,
        "for_over_iter": 10,
        "str_iter_next": 2,
        "next_exhausted": 99,  # StopIteration
        # iter() over range / dict / set
        "for_over_range_iter": 10,
        "next_range": 1013,
        "for_over_range_desc": 15,
        "for_over_dict_iter": 3,
        "for_over_set_iter": 12,
        "map_over_stored": 12,
        # iter(it) of a stored iterator is not released twice
        "for_over_iter_of_stored": 10,
        "assign_iter_of_stored": 10
    };
    got = {fn: get_func(eng, fn, ctypes.c_int64)() for fn in want};
    assert got == want , {
        fn: (got[fn], want[fn])
        for fn in want
        if got[fn] != want[fn]
    };
    # a returned iterator owns its local source collection: both items drop
    drops = get_func(eng, "iterator_item_drop_count", ctypes.c_int64);
    before = drops();
    assert get_func(eng, "returned_iterator_values", ctypes.c_int64)() == 268;
    assert drops() - before == 2;
}

# --- #6403: iter()/next() are positional-only; the keyword form is rejected ---
# The checker must not type a keyword call (`next(it=...)`) that the backend
# cannot lower — it should fail at the type level like CPython does.
test "iter next keyword arg rejected" {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, "iter_kwarg_rejected.jac")),
        options=native_force_opts()
    );
    errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert errs , "expected a type error for next(it=...)";
    assert any("No matching overload" in e for e in errs) , errs;
}

# --- #6403 M2: user-defined __iter__/__next__ bridged into the protocol ---
test "iter_user: a user __iter__/__next__ drives the protocol" {
    (eng, _) = compile_native("iter_user.jac");
    want = {
        "user_self_for": 10,
        "user_self_for_var": 3,  # borrowed var
        "user_separate_for": 6,  # a separate iterator object
        "user_iter_next": 1011,
        "user_map_compose": 6,
        "user_break": 3,
        "user_cross_fn": 10,
        "user_next_propagates": 42,  # a non-StopIteration error propagates
        "user_inherited_iter": 6  # __iter__/__next__ inherited from a base
    };
    got = {fn: get_func(eng, fn, ctypes.c_int64)() for fn in want};
    assert got == want , {
        fn: (got[fn], want[fn])
        for fn in want
        if got[fn] != want[fn]
    };
}

test "iterator bindings retain borrowed objects across cleanup and reassignment" {
    (engine, _) = compile_native("iterator_object_ownership.jac");
    for name in [
        "enumerate_keeps_elements",
        "iter_keeps_elements",
        "zip_keeps_elements"
    ] {
        assert get_func(engine, name, ctypes.c_int64)() == 42;
    }
}
