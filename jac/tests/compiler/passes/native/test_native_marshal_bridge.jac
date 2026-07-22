"""Tests for sv<->na marshal bridge robustness.

Covers view identity dedup, cycle safety, dict/set/list[str] result
marshalling, view round-trip arguments, and write-through mutation.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import jaclang.jac0core.unitree as uni;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

def compile_fixture(fixture: str) -> tuple[ExecutionEngine | None, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    return (ir.gen.native_engine, ir);
}

def bridge_fns -> tuple[dict, ExecutionEngine | None] {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function,
        init_native_globals
    }
    (eng, ir) = compile_fixture("marshal_bridge.na.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
    init_native_globals(eng, ir.gen.interop_manifest);
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    fns: dict = {};
    for (fname, func_layout) in layout.functions.items() {
        wrapper = wrap_native_function(
            eng, func_layout, ct_classes, enum_maps, {}, layout=layout
        );
        if wrapper is not None {
            fns[fname] = wrapper;
        }
    }
    return (fns, eng);
}

test "shared substructure dedups to one view" {
    (fns, eng) = bridge_fns();
    p = fns["make_shared"]();
    assert p.left is p.left;
    assert p.left is p.right;
    assert p.left == p.right;
    assert p.left.val == 7;
}

test "cyclic graph closes with identity" {
    (fns, eng) = bridge_fns();
    a = fns["make_cycle"]();
    assert a.nxt.nxt is a;
    assert a.nxt.nxt == a;
    seen: set = set();
    cur = a;
    hops = 0;
    while (id(cur) not in seen and hops < 10) {
        seen.add(id(cur));
        cur = cur.nxt;
        hops += 1;
    }
    assert hops == 2 , f"visited-set walk took {hops} hops";
    assert a.val == 1 and a.nxt.val == 2;
}

test "dict result marshals to python dict" {
    (fns, eng) = bridge_fns();
    assert fns["make_map"]() == {1: 10, 2: 20};
    assert fns["make_strmap"]() == {"a": 1, "b": 2};
}

test "set result marshals to python set" {
    (fns, eng) = bridge_fns();
    assert fns["make_set"]() == {1, 2, 3};
}

test "list of str marshals to strings" {
    (fns, eng) = bridge_fns();
    result = fns["make_strlist"]();
    assert list(result) == ["x", "yy"];
    assert result == ["x", "yy"];
}

test "views round-trip as native arguments" {
    (fns, eng) = bridge_fns();
    assert fns["sum_list"](fns["make_list"](4)) == 12;
    assert fns["child_val"](fns["make_child"]()) == 5;
}

test "struct view scalar write goes to native memory" {
    (fns, eng) = bridge_fns();
    p = fns["make_shared"]();
    p.left.val = 99;
    assert p.right.val == 99;
}

test "congruence hand-rolled property cases" {
    import random;
    (fns, eng) = bridge_fns();
    rng = random.Random(1234);
    cases = [0, 1, 64] + [rng.randrange(0, 50) for _i in range(25)];
    for n in cases {
        expected = [i * 2 for i in range(n)];
        assert list(fns["make_list"](n)) == expected;
        assert fns["sum_list"](fns["make_list"](n)) == sum(expected);
    }
}
