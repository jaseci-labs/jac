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
one, and "is anything dispatched through me" is asked of the whole import
closure instead of of one module.

The pair therefore agrees on carrying the header rather than on flat. A base
with a subclass is a base wherever that subclass is declared, so `SlotBase`
gains the header here exactly as a base with a same-module subclass always
did; the old flat answer was not a leaner decision, it was the registry
failing to see the subclass. What this test holds the header rule to is that
the two agree, and that a child never adopts field indices through a narrower
header than the base assigned them behind.

`inherited_slot_novt.jac` is the control that places the fault. It overrides
nothing, so if the override were what forced the vtable it would have lowered
all along. It did not: it refused for exactly the same reason, which is what
identifies the header decision rather than the override as the cause.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     CHILD = "inherited_slot_child.jac",
     NOVT = "inherited_slot_novt.jac";


"""Compile a fixture natively under the census; return (module, census)."""
def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                no_ir_cache=True,
                aot_mode=True
            )
        );
    } finally {
        census = na_census_end();
    }
    assert not prog.errors_had , (f"{fixture}: {[str(e) for e in prog.errors_had]}");
    return (ir, census);
}


"""The census seams recorded across every module of the compile."""
def _all_seams(census: dict) -> list[str] {
    out: list[str] = [];
    for (_, rec) in census.items() {
        for s in (rec.get("seams") or []) {
            out.append(str(s));
        }
    }
    return out;
}


test "a child of a flat imported base carries the same header its base does" {
    (ir, _census) = _compile(CHILD);
    reg = ir.gen.layout_registry;
    assert reg is not None , "no layout registry was built";
    base = reg.get_layout("SlotBase");
    child = reg.get_layout("SlotChild");
    assert base is not None and child is not None , (
        f"both layouts must be present, got: {sorted(reg.layouts)}"
    );
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"the header slots must agree or no slot assignment satisfies both: "
        f"base vtable_ptr_slot={base.vtable_ptr_slot}, "
        f"child vtable_ptr_slot={child.vtable_ptr_slot}"
    );
    assert child.has_vtable == base.has_vtable , (
        "the child must carry exactly the header its base does, or the "
        "inherited field indices it adopts do not line up: "
        f"base has_vtable={base.has_vtable}, child has_vtable={child.has_vtable}"
    );
}


test "the child adopts the base's slot assignment verbatim" {
    (ir, _census) = _compile(CHILD);
    reg = ir.gen.layout_registry;
    base = reg.get_layout("SlotBase");
    child = reg.get_layout("SlotChild");
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
    (_ir, census) = _compile(CHILD);
    seams = _all_seams(census);
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
    (ir, census) = _compile(NOVT);
    reg = ir.gen.layout_registry;
    base = reg.get_layout("SlotBase");
    child = reg.get_layout("SlotChildFlat");
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"base {base.vtable_ptr_slot} != child {child.vtable_ptr_slot}"
    );
    seams = _all_seams(census);
    for fn in ["SlotChildFlat.store_inherited", "SlotChildFlat.read_inherited"] {
        hits = [
            s
            for s in seams
            if s.startswith(f"{fn}: ")
        ];
        assert not hits , f"'{fn}' must lower once the headers agree: {hits}";
    }
}
