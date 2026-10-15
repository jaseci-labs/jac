"""A native primitive method call honours every argument it is given, or the
call is refused and its function runs on the Python tier (issue #9823).

The native lowering of `str.index`, `str.rfind`, `str.rindex`, `str.count`,
`str.center`/`ljust`/`rjust`, `list.index`, `tuple.index` and the multi-set
`set` operations used to read only some of their arguments and drop the rest,
so `s.index("/>", 5)` returned the first match in the whole string. Each such
call now either lowers with every argument or is refused with E5092.
"""

import os;
import ctypes;
import jaclang.compiler.backends.native.llvm.ir as ir;
import from jaclang.compiler.backends.native.primitives_native {
    EmitArgs,
    NativeStrEmitter
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, get_func }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "method_args_honoured.jac",
     TEXT = "ab/> cd <img x />";

glob _MEMO: list[any] = [];

"""Compile the fixture natively without the IR cache; return (seams, ir)."""
def compile_fixture -> tuple[any, ...] {
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=path,
            options=CompileOptions(force_codespace='native', no_ir_cache=True)
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(path));
    seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    return (seams, ir, );
}

def measured -> tuple[any, ...] {
    if not _MEMO {
        _MEMO.append(compile_fixture());
    }
    return _MEMO[0];
}

"""The one seam owned by `name`, or the empty string."""
def seam_for(seams: list[any], name: str) -> str {
    owned = [
        s
        for s in seams
        if str(s).startswith(f"{name}: ")
    ];
    return owned[0] if len(owned) == 1 else "";
}

def miss(fn: any, *args: any) -> int {
    try {
        return fn(*args);
    } except ValueError {
        return -7;
    }
}

def assert_lowered_values(cases: list[tuple[str, int]]) {
    (seams, ir) = measured();
    for (name, expected) in cases {
        assert not seam_for(seams, name) , f"{name} must lower natively: {seams}";
        got = get_func(ir.gen.native_engine, name, ctypes.c_int64)();
        assert got == expected , f"{name}: native {got}, CPython {expected}";
    }
}


test "str search methods honour start and end" {
    assert_lowered_values(
        [
            ("index_from", TEXT.index("/>", 5)),
            ("find_window", TEXT.find("/>", 0, 3)),
            ("rfind_window", TEXT.rfind("/>", 0, 6)),
            ("rindex_window", TEXT.rindex("/>", 0, 6)),
            ("rfind_from", TEXT.rfind("/>", 5)),
            ("count_from", TEXT.count("/>", 5)),
            ("count_window", TEXT.count("/>", 0, 6)),
            ("find_negative_window", TEXT.find("img", -9, -2)),
            ("find_empty_past_end", "abc".find("", 5)),
            ("rfind_empty_window", TEXT.rfind("", 0, 4)),
            ("count_empty_window", TEXT.count("", 0, 4)),
            ("rfind_overlapping", "aaa".rfind("aa")),
            ("index_window_miss", miss("ab/> cd".index, "/>", 3)),
            ("rindex_window_miss", miss("ab/> cd".rindex, "/>", 0, 3))
        ]
    );
}


test "str padding honours the fill character" {
    assert "ab".center(6, "─") == "──ab──";
    assert_lowered_values(
        [
            ("center_fill", 1),
            ("ljust_fill", 1),
            ("rjust_zero_fill", 1),
            ("center_multibyte_fill", 1),
            ("center_default_fill", 1),
            ("pad_negative_width", 1),
            ("pad_rejects_long_fill", 1)
        ]
    );
}


test "list and tuple index honour start and stop" {
    xs = [7, 1, 7, 3];
    t = (7, 7, 1, 2);
    assert_lowered_values(
        [
            ("list_index_from", xs.index(7, 1)),
            ("list_index_negative_start", xs.index(7, -2)),
            ("list_index_window_miss", miss(xs.index, 7, 3, 4)),
            ("tuple_index_from", t.index(7, 1)),
            ("tuple_index_window_miss", miss(t.index, 7, 2)),
            ("tuple_index_miss", miss(t.index, 9))
        ]
    );
}


test "set operations fold over every argument" {
    assert_lowered_values(
        [
            ("set_union_many", len({1}.union({2}, {3, 1}))),
            ("set_intersection_many", len({1, 2, 3}.intersection({1, 2}, {2, 3}))),
            ("set_difference_many", len({1, 2, 3, 4}.difference({1}, {4}))),
            ("set_update_many", 3),
            ("set_intersection_update_many", 1),
            ("set_difference_update_many", 2)
        ]
    );
}


test "str.encode lowers a utf-8 codec name and refuses any other" {
    s = "héllo";
    assert_lowered_values(
        [("encode_utf8_names", len(s.encode("utf-8")) * 100 + len(s.encode("UTF8")))]
    );
    (seams, _ir) = measured();
    assert "[E5092]" in seam_for(seams, "encode_latin1") , str(seams);
}


test "keyword arguments to a native method refuse instead of vanishing" {
    (seams, _ir) = measured();
    for name in ["expandtabs_keyword", "to_bytes_signed_keyword"] {
        seam = seam_for(seams, name);
        assert "[E5092]" in seam and "keyword argument for native method" in seam , (
            f"{name} must refuse its keyword argument, got: {seams}"
        );
    }
}


def lazy_zfill(self: NativeStrEmitter, ctx: any, target: any, args: list[any]) -> any {
    return target;
}

test "a lowering that leaves an argument unread is refused" {
    (seams, _ir) = measured();
    assert not seam_for(seams, "zfill_three") , str(seams);
    original = NativeStrEmitter.emit_zfill;
    NativeStrEmitter.emit_zfill = lazy_zfill;
    try {
        (lazy_seams, _lazy_ir) = compile_fixture();
    } finally {
        NativeStrEmitter.emit_zfill = original;
    }
    seam = seam_for(lazy_seams, "zfill_three");
    assert "[E5092]" in seam and "str.zfill(argument 1)" in seam , str(lazy_seams);
}


test "EmitArgs records the positions a lowering reads" {
    values = [ir.Constant(ir.IntType(64), k) for k in range(4)];
    args = EmitArgs(values);
    assert args.unread() == [0, 1, 2, 3];
    assert args[0] is values[0] and args[-1] is values[3];
    assert args.unread() == [1, 2];
    assert args[1:2] == [values[1]];
    assert args.unread() == [2];
    assert len(args) == 4 and args.unread() == [2];
    assert list(args) == values;
    assert args.unread() == [];
    assert EmitArgs([]).unread() == [];
}
