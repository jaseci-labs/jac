"""List subscript bounds checks take one unsigned compare on the hot path.

`xs[i]` / `xs[i] = v` follow Python: a negative index counts from the end and
anything still out of range raises IndexError. The in-range case is a single
`index <u len` compare (a negative index is a huge unsigned value), weighted so
the in-range edge stays the fall-through; the negative wrap and the raise live
in a cold block. The IR test pins that shape; the run tests pin the semantics.
"""

import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func }

test "list subscripts check the in-range case with one weighted unsigned compare" {
    text = str(compile_native_ir("list_index_check.jac").gen.llvm_ir);
    lines = text.splitlines();
    for tag in ("idx", "setidx") {
        name = tag + ".inrange";
        cmp = [
            ln
            for ln in lines
            if name in ln and " = icmp " in ln
        ];
        assert cmp , f"{tag}: no in-range compare";
        assert all("icmp ult" in ln for ln in cmp) , f"{tag}: in-range compare is not unsigned";
        br = [
            ln
            for ln in lines
            if ln.strip().startswith("br i1") and name in ln
        ];
        assert br , f"{tag}: no branch on the in-range compare";
        assert all("!prof" in ln for ln in br) , f"{tag}: in-range branch is not weighted";
        assert (tag + ".wrap") in text , f"{tag}: no cold wrap block";
    }
}

test "list reads follow Python index semantics" {
    (eng, _) = compile_native("list_index_check.jac");
    f = get_func(eng, "read_at", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert [f(5, 2), f(5, -1), f(5, -5)] == [20, 40, 0];
    assert [f(5, 5), f(5, -6), f(0, 0), f(0, -1)] == [-999, -999, -999, -999];
    big = 1 << 62;
    assert [f(5, big), f(5, -big), f(5, -(1 << 63))] == [-999, -999, -999];
    w = get_func(eng, "walk", ctypes.c_int64, ctypes.c_int64);
    assert w(1000) == 0;
}

test "list writes follow Python index semantics" {
    (eng, _) = compile_native("list_index_check.jac");
    f = get_func(
        eng, "write_at", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(4, 1, 7) == 7 * 31 * 31;
    assert f(4, -1, 7) == 7;
    assert f(4, -4, 7) == 7 * 31 * 31 * 31;
    assert f(4, 4, 7) == -999;
    assert f(4, -5, 7) == -999;
    assert f(4, -(1 << 63), 7) == -999;
}
