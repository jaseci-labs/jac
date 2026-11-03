"""MIR's ownership pass: the nogc lowering of a nogc-enforced unit.

Under `--memory nogc` a nogc-enforced unit no longer runs reference counting.
Every heap value has one owner; a move hands it on without a retain, a read
through a field or an element is a borrow that takes no count, borrowed text
reaching an owner is copied, and only owned slots drop at scope end. These
tests pin that the pass emits no retain on the fixtures that exercise those
rules, that the per-type drop glue and the vtable drop slot are generated, and
that a fixture covering the remaining move shapes agrees with every other
profile and with the Python backend.
"""

import os;
import re;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "nogc_identity"
     );

def _unit_ir(name: str) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(aot_mode=True, memory_profile="nogc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

test "moves, borrows and copies under nogc emit no retain" {
    for name in [
        "own_param_drop.jac",
        "borrow_then_move.jac",
        "receiver_borrow.jac",
        "view_cursor.jac",
        "linked_list.jac",
        "named_move_containers.jac",
        "ownership_moves.jac"
    ] {
        text = _unit_ir(name);
        assert "__jac_rt_retain" not in text , f"{name}: the ownership pass retained";
    }
}

test "class objects, take, swap, copied text and lent lists move ownership once" {
    out = assert_native_identity(os.path.join(FIXTURES, "ownership_moves.jac"));
    assert out.splitlines()
        == [
            "built 5 s5",
            "label copied 3",
            "a.part=3 b.part=1",
            "took 2",
            "drop part 2",
            "drop slot b",
            "drop part 1",
            "drop slot a",
            "drop part 3",
            "31",
            "borrowed 3",
            "drop part 9",
            "drop part 8",
            "drop part 7",
            "9",
            "drop slot copied",
            "drop part 40",
            "drop slot s5",
            "drop part 5",
            "done"
        ] , out;
}

test "a nogc class carries its drop glue and its exact drop body in vtable slot 2" {
    text = _unit_ir("dyn_drop_base.jac");
    assert "__drop_glue" in text , "no per-type drop glue was generated";
    tables = [
        line
        for line in text.splitlines()
        if re.match(r'@"[^"]*__vtable" = ', line)
    ];
    assert tables , "no vtable was emitted";
    for line in tables {
        entries = line.split("[", 2)[-1].split(", ");
        assert len(entries) >= 3 and ".__drop" in entries[2] , (
            f"vtable drop slot is empty: {line[:400]}"
        );
    }
}

test "a fresh list declared list[&T] is lent and drops no element" {
    text = _unit_ir("view_cursor.jac");
    assert "__jac_rt_list_lend" in text , "the list of borrows was not lent";
}

test "the nogc invariant rejects retain and release calls, not their declarations" {
    import from jaclang.compiler.backends.native.entry_points { _scan_rc_machinery }
    (found, _) = _scan_rc_machinery(
        'declare void @"__jac_rt_release"(i8*)\n'
            + '  call void @"__jac_rt_retain"(i8* %".3")\n'
            + '  call void @"__jac_rt_any_release"(i64 %"t", i64 %"p")\n'
            + '  call void @"__jac_rt_drop"(i8* %".4")\n'
    );
    assert found == ["__jac_rt_any_release", "__jac_rt_retain"] , found;
}

test "a nogc unit drops through the drop entry points, never the RC ones" {
    text = _unit_ir("str_field_leaks.jac");
    assert "__jac_rt_drop" in text , "no drop entry point was emitted";
    for marker in ["__jac_rt_retain", "__jac_rt_release", "__jac_rt_any_release"] {
        assert marker not in text , f"{marker} in a nogc unit";
    }
}
