"""Runtime attribute reflection refuses on the native lane instead of vanishing.

`getattr`, `setattr`, `hasattr`, `delattr`, `vars`, `dir`, and `callable` read
or write an attribute chosen at runtime. Native lowers `has` fields to fixed
struct offsets and keeps no name table beside them, so there is nothing for a
runtime name to index -- the family has no native representation at all, and
every one of their emitters is a `return None` stub.

`None` was not the diagnostic it looked like. These names live in the type
registry's builtin vocabulary, so `classify_call` tags them `CallKind.BUILTIN`,
and the codegen call path suppresses its own `E5092` for exactly that kind
(`if _call_kind != "builtin"`). An unlowered reflection call therefore produced
no value, no call, and no diagnostic: `setattr(f, "x", 5)` compiled clean as a
no-op, `print(hasattr(f, "x"))` printed a blank line, and `jac nacompile` --
the mode whose contract is "loud errors, never a demotion" -- wrote a binary
that silently disagreed with the same source run on Python.

The fix puts the family where the other statically-known refusals already
live, which is upstream of that suppression entirely.
`NATIVE_UNLOWERABLE_BUILTINS` joins `NATIVE_SUPPORTED_STDLIB` as compile-time
vocabulary in `codeinfo`, `native_capability_violations` reports a call to one
as a violation, and #8206's partition then answers for placement: a call with
an owning callable demotes that callable to a seam and leaves its siblings
native, while one at module scope keeps the whole-module refusal. The family
never reaches lowering, so the codegen suppression never sees it.

The suppression itself is left alone here on purpose. Dropping it -- so that
any builtin outrunning its emitter is a stable `E5092` rather than silence --
is the right end state, but it is not free: it currently surfaces two further
gaps, an untyped `set()` (idiomatic across this tree, and fatal to the sealed
`unitree.jac` root) and `enumerate` inside a generator expression. Those want
their own change, with their own fixes; widening this one to carry them would
trade a verified fix for an open-ended one.
"""

import ctypes;
import os;
import from jaclang.compiler.passes.main.capability_check_pass {
    native_capability_violations,
    native_capability_demotion_owner,
    partition_native_capability_violations
}
import from jaclang.jac0core.codeinfo { NATIVE_UNLOWERABLE_BUILTINS }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );


"""Forced-native options that skip the IR cache."""
def _opts -> CompileOptions {
    return CompileOptions(
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True
    );
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir, );
}


"""Compile a fixture under the demotion census; return (program, module, census)."""
def _compile_with_census(fixture: str) -> tuple {
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    } finally {
        census = na_census_end();
    }
    return (prog, ir, census, );
}


"""The error codes a compiled program reported."""
def _codes(prog: any) -> list[str] {
    return [
        str(alrt.code.code)
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
}


"""The builtin names the capability gate rejects for a fixture."""
def _rejected_builtins(fixture: str) -> list[str] {
    (_prog, ir) = _compile_native(fixture);
    assert ir is not None , f"{fixture} produced no module";
    return [
        str(v[2])
        for v in native_capability_violations(ir)
        if v[1] == "builtin"
    ];
}


"""The census seam list recorded for a fixture path."""
def _seams_of(census: dict, fixture: str) -> list[str] {
    rec = census.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}


test "a reflection call is a capability violation, not a silent drop" {
    assert _rejected_builtins("reflection_entry_hasattr.jac") == ["hasattr"] , (
        "the capability gate never looked at builtin calls, so `hasattr` "
        "reached codegen, lowered to nothing, and printed a blank line where "
        "Python prints True"
    );
}


test "the whole vocabulary is gated, not just the name that was reported" {
    assert NATIVE_UNLOWERABLE_BUILTINS
        == {"callable", "delattr", "dir", "getattr", "hasattr", "setattr", "vars"} , (
        "the gate is the single source of truth for which builtins have no "
        "native lowering; a name added to the registry without an emitter "
        "belongs here or it silently drops"
    );
}


test "a module-scope reflection call refuses the whole module" {
    (prog, ir) = _compile_native("reflection_entry_hasattr.jac");
    assert "E5090" in _codes(prog) , (
        "`with entry` has no owning callable to absorb the construct as a "
        f"seam, so the refusal is module-wide, got: {[str(e) for e in prog.errors_had]}"
    );
    assert any("hasattr" in str(e) for e in prog.errors_had) , (
        f"the diagnostic must name the builtin it refuses: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert ir.gen.llvm_ir is None , (
        "a binary that disagrees with the same source on Python is worse "
        "than a refusal"
    );
}


test "statement position refuses too" {
    (prog, _ir) = _compile_native("reflection_setattr_stmt.jac");
    assert "E5090" in _codes(prog) , (
        "an expression statement discards its value, so a reflection call "
        "that lowered to nothing left no trace at all -- `setattr` compiled "
        f"clean and the field kept its old value, got: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert any("setattr" in str(e) for e in prog.errors_had) , (
        f"the diagnostic must name `setattr`: {[str(e) for e in prog.errors_had]}"
    );
}


test "reflection beside a shimmed import refuses instead of crashing" {
    (prog, ir) = _compile_native("reflection_shimmed_import.jac");
    assert "E5090" in _codes(prog) , (
        "the unlowered call handed a null to its consumer; with an na_stdlib "
        "module pulled in beside it the null reached a dereference and the "
        "compile died with `Segmentation fault at address 0x0` and no "
        f"diagnostic at all, got: {[str(e) for e in prog.errors_had]}"
    );
    assert any("hasattr" in str(e) for e in prog.errors_had) , (
        f"the refusal must still name the builtin: {[str(e) for e in prog.errors_had]}"
    );
    assert ir.gen.llvm_ir is None , (
        "refusing the module is what keeps the null from being created"
    );
}


test "a body-scoped reflection call demotes its own function" {
    (_prog, ir) = _compile_native("reflection_in_function.jac");
    viols = [
        v
        for v in native_capability_violations(ir)
        if v[1] == "builtin"
    ];
    assert len(viols) == 1 , f"expected one violation, got {viols}";
    owner = native_capability_demotion_owner(viols[0][0]);
    assert owner is not None , (
        "`probe` is a module-level function and can absorb the construct as "
        "a native seam, so the partition must hand it an owner rather than "
        "escalating to a module refusal"
    );
    assert owner.name_ref.sym_name == "probe" , (
        f"the seam belongs to the function that reflects, got {owner.name_ref}"
    );
    (fatal, demotable) = partition_native_capability_violations(viols);
    assert fatal == [] , f"a demotable violation must not be fatal, got {fatal}";
    assert len(demotable) == 1 , f"expected one demotable unit, got {demotable}";
}


test "the demotion leaves its siblings native" {
    (prog, ir, census) = _compile_with_census("reflection_in_function.jac");
    assert "E5090" not in _codes(prog) , (
        "a body-scoped violation demotes rather than refusing, exactly as a "
        f"body-scoped Python import does, got: {[str(e) for e in prog.errors_had]}"
    );
    _all_seams = _seams_of(census, "reflection_in_function.jac");
    seams = [
        s
        for s in _all_seams
        if s.startswith("probe: ")
    ];
    assert len(seams) == 1 , (
        f"`probe` must be recorded as a native seam under the name the "
        f"demotion census and the seal waivers already use for it, got: "
        f"{_all_seams}"
    );
    assert "hasattr" in seams[0] , (
        f"the seam reason must name the blocking builtin: {seams[0]}"
    );
    assert not [
        s
        for s in _all_seams
        if s.startswith("pure: ")
    ] , (f"demoting `probe` must not drag its siblings off native: {_all_seams}");
    assert ir.gen.llvm_ir is not None , (
        "the module still lowers -- only the reflecting function is a seam"
    );
}
