"""Inherited fields through a consumer subclass of an imported archetype (#8201).

`LayoutPass` is a per-module pass, and the archetypes it collects come from the
module's own tree. A consumer that writes `obj Kid(Base)` over an imported
`Base` therefore linearizes a base whose declaration it never sees, and the
ancestor-flattening loop skipped it: `Kid` laid out with its own fields only,
so every inherited read, write, and constructor keyword refused (E5092) at
every `AtomTrailer` depth.

The importing codegen already merges the defining module's layouts into the
consumer's registry -- it just did so after the only pass that reads them. The
merge now hands the registry back for one adoption round, and a subclass takes
its primary ancestor's slot assignment verbatim, so the ancestor's own methods
and the consumer's reads agree about where a field lives.

The subprocess pair is the contract: running the same fixture through the
server pathway (CPython) and through a native binary must print identical
lines, so the field *values* are pinned and not merely the fact that something
lowered.

A vtable-less imported base was the shape that stayed refused. `Anchor` puts
its first field at slot 0 because its own module gives it no vtable, while a
subclass claimed that slot for a vtable of its own -- one it received merely
for having a base, since `needs_vtable` asked `bool(parents)` alongside the
two disjuncts that ask whether anything is dispatched through the class. Where
nothing is, that header is a habit rather than a requirement: adoption drops
it, both units read the field at the same offset, and the E5092 is paid out.
A class something IS dispatched through keeps its header and its refusal --
that pair genuinely has no assignment satisfying both.
"""

import contextlib;
import io;
import os;
import from tests.support {
    TESTS_DIR,
    by_source_name,
    native_force_opts,
    source_spelled,
    sv_run,
    na_run,
    same_lines
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a fixture natively and hand back the program and the module."""
def compile_native(fixture: str, expect_demotions: bool = False) -> tuple[any, ...] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    if not expect_demotions {
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
        assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    }
    return (prog, ir, );
}

"""The seam report a build would show on stderr for a fixture."""
def seam_report(fixture: str) -> str {
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
        );
    }
    return source_spelled(buf.getvalue());
}

"""Field name to slot index, as the consumer's registry holds it."""
def slots_of(ir: uni.Module, prog: JacProgram, name: str) -> dict[str, any] {
    layout = by_source_name(get_layout_registry(ir, prog).layouts).get(name);
    assert layout is not None , f"no layout for {name}";
    return dict(layout.field_index);
}

test "a consumer subclass reads its imported base's fields with no seam" {
    seams = seam_report("xmod_inherit_main.jac");
    assert "run_probe" not in seams , (
        f"inherited field access still demotes its owner: {seams}"
    );
}

test "the subclass adopts the imported base's slot assignment" {
    (prog, ir) = compile_native("xmod_inherit_main.jac");
    base = slots_of(ir, prog, "Base");
    kid = slots_of(ir, prog, "Kid");
    assert kid["tag"] == base["tag"] , (
        f"'tag' moved between the two units: base {base} vs kid {kid}"
    );
    assert kid["depth"] == base["depth"] , (
        f"'depth' moved between the two units: base {base} vs kid {kid}"
    );
    assert kid["mine"] > max(base.values()) , (
        f"the subclass's own field must follow the inherited ones: {kid}"
    );
}

test "a two-link chain adopts the whole flattened ancestor" {
    (prog, ir) = compile_native("xmod_inherit_main.jac");
    mid = slots_of(ir, prog, "Mid");
    deep = slots_of(ir, prog, "Deep");
    for fname in ["tag", "depth", "mid"] {
        assert deep[fname] == mid[fname] , (
            f"'{fname}' moved between Mid and Deep: mid {mid} vs deep {deep}"
        );
    }
    assert deep["extra"] > max(mid.values()) , (
        f"the subclass's own field must follow the inherited ones: {deep}"
    );
}

test "the subclass's vtable is prefix-compatible with the base's" {
    (prog, ir) = compile_native("xmod_inherit_main.jac");
    reg = get_layout_registry(ir, prog);
    base = by_source_name(reg.layouts).get("Base");
    kid = by_source_name(reg.layouts).get("Kid");
    assert base is not None and kid is not None , "layouts missing";
    for mslot in base.methods {
        assert kid.method_index.get(mslot.name) == mslot.index , (
            f"method '{mslot.name}' sits at a different vtable slot in the "
            f"subclass: base {base.method_index} vs kid {kid.method_index}"
        );
    }
}

test "inherited fields answer what the server pathway answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "xmod_inherit_main.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "xmod_inherit_main.jac"));
    same_lines(sv_out, na_out, "inherited fields");
}

test "a vtable-less imported base and its subclass agree on the header" {
    # This shape used to be refused, and the refusal was recorded here as
    # unavoidable: `Anchor` puts `depth` at slot 0 because its own module
    # gives it no vtable, and `FlatKid` claimed that slot for a vtable it
    # got purely for having a base. An assignment satisfying both now
    # exists, because nothing dispatches through `FlatKid` and the header it
    # carried was a habit rather than a requirement.
    (prog, ir) = compile_native("xmod_inherit_flat_main.jac");
    reg = get_layout_registry(ir, prog);
    anchor = by_source_name(reg.layouts).get("Anchor");
    kid = by_source_name(reg.layouts).get("FlatKid");
    assert anchor is not None and kid is not None , "layouts missing";
    assert anchor.vtable_ptr_slot == kid.vtable_ptr_slot , (
        f"the headers must agree or no slot assignment satisfies both: "
        f"Anchor {anchor.vtable_ptr_slot} vs FlatKid {kid.vtable_ptr_slot}"
    );
    assert kid.field_index.get("depth") == anchor.field_index.get("depth") , (
        f"`depth` must sit where the module that declared it put it: "
        f"Anchor {anchor.field_index} vs FlatKid {kid.field_index}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    for fn in ["read_inherited", "stays_clean"] {
        assert fn in layout.functions , (
            f"'{fn}' must lower once the headers agree: " f"{list(layout.functions)}"
        );
    }
    seams = seam_report("xmod_inherit_flat_main.jac");
    assert "read_inherited" not in seams , (
        f"the inherited read must no longer demote: {seams}"
    );
}


test "the flat pair answers what the server pathway answers" {
    # The offsets agreeing is not the same as the values being right: a
    # header fix that shifted both units consistently but wrongly would
    # still pass the layout assertions above.
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "xmod_inherit_flat_main.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "xmod_inherit_flat_main.jac"));
    same_lines(sv_out, na_out, "vtable-less imported base");
}
