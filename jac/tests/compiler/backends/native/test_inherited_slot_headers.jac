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
fields at all, and every method touching one demoted.

The rule is now inherited rather than re-derived: a class carries a vtable
when something is dispatched through it, or when an ancestor already carries
one. Intra-module hierarchies are unchanged -- a base with a local subclass
still gains the header and still passes it down. A base whose methods another
module can override is dispatched through, so `SlotBase` carries the header
in its own module and the cross-module pair agrees on it; a base with no
overridable method stays flat and its children agree on flat.

`inherited_slot_novt.jac` is the control that places the fault. It overrides
nothing, so if the override were what forced the vtable it would have lowered
all along. It did not: it refused for exactly the same reason, which is what
identifies the header decision rather than the override as the cause.
"""

import os;
import ctypes;
import from tests.support { TESTS_DIR }
import from tests.support {
    by_source_name,
    compile_mir,
    compile_native,
    get_func,
    source_spelled
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CHILD = "inherited_slot_child.jac",
     NOVT = "inherited_slot_novt.jac";


"""Compile a fixture natively; return its module (the layout registry
tests read the tree, so they are kernel suite material)."""
def _compile(fixture: str) -> any {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(force_codespace="native", aot_mode=True)
    );
    assert not prog.errors_had , (f"{fixture}: {[str(e) for e in prog.errors_had]}");
    return ir;
}


"""Every function the decision step demoted across every unit of the
fixture's compile, spelled by source name."""
def _all_demoted(fixture: str) -> list[str] {
    fx = compile_mir(
        fixture, FIXTURES, CompileOptions(force_codespace="native", aot_mode=True)
    );
    return [
        source_spelled(demotion.symbol)
        for unit in fx.result.units
        for demotion in unit.demoted
    ];
}


"""The demoted symbols naming `fn` (a `Class.method`)."""
def _hits(demoted: list[str], fn: str) -> list[str] {
    return [
        sym
        for sym in demoted
        if sym == fn or sym.endswith(f".{fn}")
    ];
}

test "an abstract interface hierarchy across modules lowers with nothing demoted" {
    demoted = _all_demoted("abstract_slot_child.jac");
    assert not demoted , str(demoted);
}

test "an abstract interface keeps its dispatch header across imported subclasses" {
    module = _compile("abstract_slot_child.jac");
    registry = module.gen.layout_registry;
    interface = by_source_name(registry.layouts)["SlotInterface"];
    storage = by_source_name(registry.layouts)["SlotStorage"];
    child = by_source_name(registry.layouts)["SlotLeaf"];
    assert interface.vtable_ptr_slot == 0;
    assert storage.vtable_ptr_slot == child.vtable_ptr_slot == 0;
    assert storage.field_index["values"] == child.field_index["values"];
}

test "separately compiled abstract dispatch and inherited fields execute together" {
    (engine, _) = compile_native("abstract_slot_child.jac");
    function = get_func(engine, "run_abstract_slots", ctypes.c_int64);
    assert function() == 17;
}

test "an imported dispatcher invokes implementations absent from its own module" {
    (engine, _) = compile_native("abstract_slot_child.jac");
    function = get_func(engine, "run_imported_abstract_dispatch", ctypes.c_int64);
    assert function() == 23;
}


test "a child of an imported base carries the same header its base does" {
    ir = _compile(CHILD);
    reg = ir.gen.layout_registry;
    assert reg is not None , "no layout registry was built";
    base = by_source_name(reg.layouts).get("SlotBase");
    child = by_source_name(reg.layouts).get("SlotChild");
    assert base is not None and child is not None , (
        f"both layouts must be present, got: {sorted(by_source_name(reg.layouts))}"
    );
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"the header slots must agree or no slot assignment satisfies both: "
        f"base vtable_ptr_slot={base.vtable_ptr_slot}, "
        f"child vtable_ptr_slot={child.vtable_ptr_slot}"
    );
    assert base.has_vtable and child.has_vtable , (
        "SlotBase declares a method a module it never sees may override, and "
        "SlotChild does, so a call through a SlotBase reference must dispatch: "
        "both carry the vtable"
    );
}


test "the child adopts the base's slot assignment verbatim" {
    ir = _compile(CHILD);
    reg = ir.gen.layout_registry;
    base = by_source_name(reg.layouts).get("SlotBase");
    child = by_source_name(reg.layouts).get("SlotChild");
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
    demoted = _all_demoted(CHILD);
    for fn in [
        "SlotChild.store_inherited",
        "SlotChild.read_inherited",
        "SlotChild.bump"
    ] {
        hits = _hits(demoted, fn);
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
    demoted = _all_demoted(NOVT);
    for fn in ["SlotChildFlat.store_inherited", "SlotChildFlat.read_inherited"] {
        hits = _hits(demoted, fn);
        assert not hits , f"'{fn}' must lower once the headers agree: {hits}";
    }
}


test "the no-override control's child and base agree on the header" {
    ir = _compile(NOVT);
    reg = ir.gen.layout_registry;
    base = by_source_name(reg.layouts).get("SlotBase");
    child = by_source_name(reg.layouts).get("SlotChildFlat");
    assert base.vtable_ptr_slot == child.vtable_ptr_slot , (
        f"base {base.vtable_ptr_slot} != child {child.vtable_ptr_slot}"
    );
}
