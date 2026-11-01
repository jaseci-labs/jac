"""The native sort survives the lists that have nothing to sort.

Regression pins for the empty-list crash the ambient-import migration
surfaced (#8323 item A10b, PR #8344): `jac/tests/cli/` test modules had
been held off the native pathway by a typing import in their CLI import
closure; the moment the migration restored them, their first native run
died in `sorted()` over an empty list. The bug predates the migration --
the bubble sort's `len - 1` bound wraps unsigned for `len == 0` and the
loop body reads index 0 of a zero-element store -- but nothing native
had reached it before.

Each entry point is executed in the JIT and compared with CPython's
answer for the same program, following the isinstance-families harness
pattern.
"""

import ctypes;
import from tests.support { compile_native, native_address }

glob _ENGINE: list[any] = [];

def sorted_engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    (eng, fx) = compile_native("sorted_empty.jac");
    assert fx.llvm_ir() , "no native IR for sorted_empty.jac";
    _ENGINE.append(eng);
    return eng;
}

def native_fn(name: str) -> object {
    addr = native_address(sorted_engine(), name);
    assert addr != 0 , f"'{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}

test "sorted over an empty list returns an empty list" {
    f = native_fn("sorted_empty_len");
    assert f() == len(sorted([]));
}

test "in-place sort of an empty list is a no-op" {
    f = native_fn("sort_empty_in_place_len");
    assert f() == 0;
}

test "single-element list still sorts to itself" {
    f = native_fn("sorted_single_first");
    assert f() == sorted([7])[0];
}

test "two elements still swap into order" {
    f = native_fn("sorted_pair_first");
    assert f() == sorted([9, 3])[0];
}

test "an emptied comprehension result sorts without a read" {
    f = native_fn("sorted_empty_from_compr");
    assert f() == 0;
}
