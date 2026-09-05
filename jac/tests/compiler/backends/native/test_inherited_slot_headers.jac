"""A subclass and its imported base agree on the object header.

`needs_vtable` asked `bool(parents)` -- "do I have a base" -- alongside two
disjuncts that ask something else entirely: "is anything dispatched through
me". A base whose only subclass lives in another module is nobody's parent in
its own registry, so it came out flat; the child, merely for having a base,
came out with a vtable pointer in header slot 0. Every inherited field then
sat one slot further along in the child than in the base that declared it.

`adopt_imported_bases` is what makes two units agree on an object: the child
adopts its ancestor's field indices verbatim. That is sound only when the
headers are the same width, so `headers_agree` refused the pair and the
adoption was declined -- leaving the child's layout without the inherited
fields at all, and every method touching one demoted to a seam.

The rule is now inherited rather than re-derived: a class carries a vtable
when something is dispatched through it, or when an ancestor already carries
one. Intra-module hierarchies are unchanged -- a base with a local subclass
still gains the header and still passes it down -- and the cross-module pair
now agrees on flat.

`inherited_slot_novt.jac` is the control that places the fault. It overrides
nothing, so if the override were what forced the vtable it would have lowered
all along. It did not: it refused for exactly the same reason, which is what
identifies the header decision rather than the override as the cause.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CHILD = "inherited_slot_child.jac",
     NOVT = "inherited_slot_novt.jac";


"""Compile a fixture natively under the coverage; return (module, coverage)."""
def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(
                force_codespace='native',
                force_target_program=True,
                aot_mode=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    assert not prog.errors_had , (f"{fixture}: {[str(e) for e in prog.errors_had]}");
    return (ir, coverage);
}


"""The coverage seams recorded across every module of the compile."""
def _all_seams(coverage: dict) -> list[str] {
    out: list[str] = [];
    for (_, rec) in coverage.items() {
        for s in (rec.get("seams") or []) {
            out.append(str(s));
        }
    }
    return out;
}


test "a child of a flat imported base carries the same header its base does" {
    (ir, _coverage) = _compile(CHILD);
    reg = ir.gen.layout_registry;
    assert reg is not None , "no layout registry was built";
    base = reg.layouts.get("SlotBase");
    child = reg.layouts.get("SlotChild");
    assert base is not None and child is not None , (
        f"both layouts must be present, got: {sorted(reg.layouts)}"
    );
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"the header slots must agree or no slot assignment satisfies both: "
        f"base vtable_ptr_slot={base.vtable_ptr_slot}, "
        f"child vtable_ptr_slot={child.vtable_ptr_slot}"
    );
    assert not child.has_vtable , (
        "nothing is dispatched through SlotChild and its base is flat, so it "
        "must not carry a vtable its base lacks"
    );
}


test "the child adopts the base's slot assignment verbatim" {
    (ir, _coverage) = _compile(CHILD);
    reg = ir.gen.layout_registry;
    base = reg.layouts.get("SlotBase");
    child = reg.layouts.get("SlotChild");
    for finfo in base.fields {
        assert finfo.name in child.field_index , (
            f"the child's layout is missing the inherited field "
            f"'{finfo.name}' -- declined adoption leaves it out entirely: "
            f"{sorted(child.field_index)}"
        );
        assert child.field_index[finfo.name] == finfo.index , (
            f"inherited field '{finfo.name}' sits at {child.field_index[
                finfo.name
            ]} in the child and {finfo.index} in the base that declared it; "
            f"the two units would read the object at different offsets"
        );
    }
    assert "own_field" in child.field_index , (
        "the child's own field must still be placed after the adopted ones"
    );
}


test "the methods that touch an inherited slot lower instead of demoting" {
    (_ir, coverage) = _compile(CHILD);
    seams = _all_seams(coverage);
    for fn in [
        "SlotChild.store_inherited",
        "SlotChild.read_inherited",
        "SlotChild.bump"
    ] {
        hits = [
            s
            for s in seams
            if s.startswith(f"{fn}: ")
        ];
        assert not hits , (
            f"'{fn}' reads or writes a slot its base declares; with the "
            f"headers agreed it must lower. Got: {hits}"
        );
    }
}


test "the no-override control lowers too, which places the fault on the header" {
    # This fixture overrides nothing. It refused for the same reason the
    # overriding one did, so the override was never what forced the vtable --
    # the header decision was.
    (ir, coverage) = _compile(NOVT);
    reg = ir.gen.layout_registry;
    base = reg.layouts.get("SlotBase");
    child = reg.layouts.get("SlotChildFlat");
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"base {base.vtable_ptr_slot} != child {child.vtable_ptr_slot}"
    );
    seams = _all_seams(coverage);
    for fn in ["SlotChildFlat.store_inherited", "SlotChildFlat.read_inherited"] {
        hits = [
            s
            for s in seams
            if s.startswith(f"{fn}: ")
        ];
        assert not hits , f"'{fn}' must lower once the headers agree: {hits}";
    }
}
