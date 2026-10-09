"""Tuple values meeting variadic slots and range subscripts natively.

A fixed-arity tuple stored into a `tuple[Any, ...]` slot is boxed element by
element into the slot's sequence instead of being bitcast into it, and a range
subscript the native backend cannot slice is refused instead of being lowered
as an index read at the range's start.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _ENG: list[any] = [];

def _engine -> any {
    if not _ENG {
        (eng, _) = compile_native("struct_unpack_variadic.jac");
        get_func(eng, "jac_entry", None)();
        _ENG.append(eng);
    }
    return _ENG[0];
}

test "an unpacked tuple in an entry global keeps its length and elements" {
    print("MARK 1: entry global", flush=True);
    eng = _engine();
    assert get_func(eng, "entry_len", ctypes.c_int64)() == 2;
    assert get_func(eng, "entry_second", ctypes.c_double)() == 2.5;
}

test "a slice of an unpacked tuple in an entry global is not empty" {
    print("MARK 2: entry slice", flush=True);
    eng = _engine();
    assert get_func(eng, "entry_head_len", ctypes.c_int64)() == 1;
    assert get_func(eng, "entry_head", ctypes.c_double)() == 1.5;
    assert get_func(eng, "zeros_head_len", ctypes.c_int64)() == 1;
}

test "mixed int and float fields box into the variadic slot" {
    print("MARK 3: mixed box", flush=True);
    eng = _engine();
    assert get_func(eng, "mixed_sum", ctypes.c_double)() == 11.5;
}

test "an annotated variadic local holds every unpacked field" {
    print("MARK 4: variadic local", flush=True);
    eng = _engine();
    assert get_func(eng, "local_tail_len", ctypes.c_int64)() == 2;
}

test "a slice of a None-narrowed optional string still lowers" {
    print("MARK 5: narrowed str", flush=True);
    eng = _engine();
    print("MARK 5a: is-not-none", flush=True);
    assert get_func(eng, "narrowed_is_not_none", ctypes.c_int64)() == 1;
    print("MARK 5b: startswith", flush=True);
    assert get_func(eng, "narrowed_startswith", ctypes.c_int64)() == 1;
    print("MARK 5c: slice+len", flush=True);
    assert get_func(eng, "narrowed_slice_len", ctypes.c_int64)() == 3;
    print("MARK 5d: slice+eq", flush=True);
    assert get_func(eng, "narrowed_slice_eq", ctypes.c_int64)() == 1;
    print("MARK 5e: combined", flush=True);
    assert get_func(eng, "narrowed_str_tail", ctypes.c_int64)() == 3;
}

test "a fixed tuple slice is refused rather than read as an index" {
    print("MARK 6: refusal compile", flush=True);
    path = os.path.join(FIXTURES, "tuple_slice_refusal.jac");
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(file_path=path, options=CompileOptions(force_codespace='native'));
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(path));
    seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    owned = [
        s
        for s in seams
        if s.startswith("tail_of_three: ")
    ];
    assert len(owned) == 1 , str(seams);
    assert "slice" in owned[0] , owned[0];
}
