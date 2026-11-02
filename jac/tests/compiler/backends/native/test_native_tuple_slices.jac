"""Tuple values meeting variadic slots and range subscripts natively.

A fixed-arity tuple stored into a `tuple[Any, ...]` slot is boxed element by
element into the slot's sequence instead of being bitcast into it, and a range
subscript is sliced or refused, never lowered as an index read at the range's
start.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
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

test "a fixed tuple slice is refused or built, never read as an index" {
    path = os.path.join(FIXTURES, "tuple_slice_refusal.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, options=native_force_opts());
    refused = [
        str(e)
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5092"
    ];
    if refused {
        assert all(", line 9," in r or ", line 10," in r for r in refused) , refused;
        assert any("slice" in r for r in refused) , refused;
    } else {
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        tail = get_func(ir.gen.native_engine, "tail_of_three", ctypes.c_int64);
        assert tail() == 267 , "t[1:3] must build (6, 7)";
    }
}
