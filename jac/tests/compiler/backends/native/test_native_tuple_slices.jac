"""Tuple values meeting variadic slots and range subscripts natively.

A fixed-arity tuple stored into a `tuple[Any, ...]` slot is boxed element by
element into the slot's sequence instead of being bitcast into it, and a range
subscript the native backend cannot slice is refused instead of being lowered
as an index read at the range's start.
"""

import ctypes;
import from tests.support { compile_mir, compile_native, get_func }

glob _ENG: list[any] = [];

def _engine -> any {
    if not _ENG {
        (eng, _) = compile_native("struct_unpack_variadic.jac");
        get_func(eng, "jac_entry", None)();
        _ENG.append(eng);
    }
    return _ENG[0];
}

test "an unpacked tuple in an entry global keeps its length and elements" {
    eng = _engine();
    assert get_func(eng, "entry_len", ctypes.c_int64)() == 2;
    assert get_func(eng, "entry_second", ctypes.c_double)() == 2.5;
}

test "a slice of an unpacked tuple in an entry global is not empty" {
    eng = _engine();
    assert get_func(eng, "entry_head_len", ctypes.c_int64)() == 1;
    assert get_func(eng, "entry_head", ctypes.c_double)() == 1.5;
    assert get_func(eng, "zeros_head_len", ctypes.c_int64)() == 1;
}

test "mixed int and float fields box into the variadic slot" {
    eng = _engine();
    assert get_func(eng, "mixed_sum", ctypes.c_double)() == 11.5;
}

test "an annotated variadic local holds every unpacked field" {
    eng = _engine();
    assert get_func(eng, "local_tail_len", ctypes.c_int64)() == 2;
}

test "a slice of a None-narrowed optional string still lowers" {
    eng = _engine();
    assert get_func(eng, "narrowed_str_tail", ctypes.c_int64)() == 3;
}

test "a fixed tuple slice is refused rather than read as an index" {
    fx = compile_mir("tuple_slice_refusal.jac");
    assert fx.is_demoted("tail_of_three") , fx.demoted();
    assert "slice" in fx.reason("tail_of_three") , fx.reason("tail_of_three");
}
