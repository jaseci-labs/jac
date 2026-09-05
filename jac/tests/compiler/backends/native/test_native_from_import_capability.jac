"""A `from`-import item is classified by the capability gate, like a bare import.

`native_capability_violations` walked an import statement's items and asked
`classify_native_import` for a module name. Only a `ModulePath` -- the
`import mod;` spelling -- ever produced one, so under forced-native placement
every `from` import was waved through without being classified at all.

That is the silent-miscompile class. `import from threading { Event }` with
`obj Holder(Event)` over it passed the gate, and the base is dropped by
`LayoutPass` on the way to a layout, so the module lowered to a `Holder` with
everything it inherits quietly missing. A refusal is the right answer, and it
is the answer the bare spelling of the same module already gave.

Inferred placement never had the hole: `scan_native_blockers` reads a `from`
import's module through `imp.from_loc` and refuses it there. So the fix is to
classify `ModuleItem` on the same terms the bare spelling gets, using the
compile-time vocabulary centralized in `codeinfo` -- and the verdicts on the
inferred path must not move at all, which is pinned below.

The four ways a `from`-import item can be legitimate are each pinned here: a
compile-time name (`ABC`, `cast`, `TypeVar`, `TypeAlias`, `ClassVar`), a
lowered stdlib module, an na_stdlib-shimmed module, and another Jac module on
the native pathway. The vocabulary is per name and not per module, so a
compile-time module's non-erasable name still refuses.

Where the refusal lands is #8206's partition: a module-scope import has no
owning callable and stays module-fatal, while a body-scoped one demotes its
function to a seam and leaves its siblings native. A property accessor is an
owning callable too -- the native lane lowers a `{ getter; }` body as a method
and the demotion coverage already names it `<Archetype>.<field>.__get__` -- so
the partition answers for it rather than falling through to a module refusal.
"""

import ctypes;
import os;
import from jaclang.compiler.passes.capability_check_pass {
    native_capability_violations
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.placement.placement { scan_native_blockers }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, native_address }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );


"""Forced-native options that skip the IR cache."""
def _opts -> CompileOptions {
    return CompileOptions(
        force_codespace='native', force_target_program=True
    );
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir, );
}


"""Compile a fixture under the demotion coverage; return (program, module, coverage)."""
def _compile_with_coverage(fixture: str) -> tuple {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    } finally {
        coverage = na_coverage_end();
    }
    return (prog, ir, coverage, );
}


"""The `Python module import` names the capability gate rejects for a fixture."""
def _rejected_imports(fixture: str) -> list[str] {
    (_prog, ir) = _compile_native(fixture);
    assert ir is not None , f"{fixture} produced no module";
    return [
        str(v[2])
        for v in native_capability_violations(ir)
        if v[1] == "Python module import"
    ];
}


"""The placement solver's blocker verdict for a snippet, or 'OK' if it has none."""
def _scan_verdict(src: str) -> str {
    (mod, had_err) = rd_parse(
        src, os.path.join(FIXTURES, "from_import_probe.jac"), prog=JacProgram()
    );
    assert not had_err , f"fixture source did not parse: {src!r}";
    (reason, _deps) = scan_native_blockers(mod, FIXTURES, allow_pub=True);
    return reason or "OK";
}


"""Wrap an import line in a module the scanner accepts apart from the import."""
def _module_with(import_line: str) -> str {
    return import_line + "\n\nwith entry {\n    print(1);\n}\n";
}


"""The error codes a compiled program reported."""
def _codes(prog: any) -> list[str] {
    return [
        str(alrt.code.code)
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
}


"""A JIT-resolved `int()` function from a compiled fixture."""
def _native_int_fn(ir: any, name: str) -> any {
    eng = ir.gen.native_engine;
    assert eng is not None , f"no native engine for '{name}'";
    addr = native_address(eng, name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}


"""The coverage seam list recorded for a fixture path."""
def _seams_of(coverage: dict, fixture: str) -> list[str] {
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}


test "a from-imported Python base is classified, not waved through" {
    assert _rejected_imports("from_import_retained_base.jac") == ["threading"] , (
        "the capability gate read the `from` import's items and found no "
        "module to classify, so an unlowerable Python base reached codegen "
        "unchallenged"
    );
}


test "the from-imported Python base refuses instead of lowering" {
    (prog, ir) = _compile_native("from_import_retained_base.jac");
    assert "E5090" in _codes(prog) , (
        "a module-scope Python `from` import has no owning callable to "
        f"absorb it, so it must keep the whole-module refusal, got: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert any("threading" in str(e) for e in prog.errors_had) , (
        f"the diagnostic must name the module it refuses: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert ir.gen.llvm_ir is None , (
        "a wrong binary is worse than a refusal: lowering `Holder` here "
        "drops everything it inherits from `Event` with no diagnostic"
    );
}


test "the inferred-placement verdict on that import is unchanged" {
    assert _scan_verdict(_module_with("import from threading { Event }"))
        == "unresolved import 'threading'" , (
        "`scan_native_blockers` already refused this import through "
        "`imp.from_loc`; closing the forced-native hole must not move the "
        "inferred path at all"
    );
}


test "a non-erasable name from a compile-time module still refuses" {
    assert _rejected_imports("from_import_abc_mixed.jac") == ["abc"] , (
        "the compile-time vocabulary is per name, not per module: `ABC` "
        "erases and `abstractmethod` does not, so listing both must refuse "
        "exactly as it does at placement"
    );
}


test "compile-time from-imports stay compile-time" {
    for fixture in [
        "abc_marker_base.jac",
        "typing_cast_identity.jac",
        "typing_typevar_glob.jac"
    ] {
        assert _rejected_imports(fixture) == [] , (
            "classifying `from`-import items must not refuse a name the "
            f"native lane erases: {fixture}"
        );
    }
}


test "a TypeAlias import no longer blocks native placement" {
    assert _scan_verdict(_module_with("import from typing { TypeAlias }")) == "OK" , (
        "native glob lowering already skips a `TypeAlias` assignment as a "
        "compile-time declaration; the import in front of it was all that "
        "still demoted the module"
    );
}


test "a TypeAlias glob module lowers clean" {
    (prog, ir) = _compile_native("typing_type_alias_glob.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the TypeAlias glob";
    assert _native_int_fn(ir, "run")() == 8 , (
        "the TypeAlias glob changed what the rest of the module computes"
    );
}


test "a ClassVar import no longer blocks native placement" {
    assert _scan_verdict(_module_with("import from typing { ClassVar }")) == "OK" , (
        "`ClassVar[T]` says where a slot lives, not what a program computes: "
        "it is annotation-only, like `TypeAlias`, and the native lane already "
        "erases it. The import in front of it was all that still refused the "
        "module at placement"
    );
}


test "a mixed typing import is still judged per name" {
    assert _scan_verdict(_module_with("import from typing { ClassVar, Optional }"))
        == "unresolved import 'typing'" , (
        "the compile-time vocabulary is per name: adding `ClassVar` to it must "
        "not wave through a `typing` import that also binds a name with no "
        "compile-time reading"
    );
}


test "a consumer links a ClassVar-importing dependency" {
    (prog, ir, coverage) = _compile_with_coverage("classvar_marker_consumer.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , (
        "no native IR for a module whose dependency's only compile-time "
        "import is `ClassVar`"
    );
    members = sorted({os.path.basename(p) for p in coverage});
    assert "classvar_marker_dep.jac" in members , (
        f"the dependency has to be in the consumer's native closure, not "
        f"refused at placement and left to Python: {members}"
    );
    assert _native_int_fn(ir, "run")() == 42 , (
        "the linked dependency has to answer across the native edge"
    );
}


test "a from import of an na_stdlib-shimmed module lowers" {
    assert _rejected_imports("from_import_shimmed_stdlib.jac") == [] , (
        "`keyword` ships as Jac source under `runtime/na_stdlib`, so a "
        "native unit supplies the name the import binds; classifying "
        "`from`-import items must not read a shimmed module as Python"
    );
    (prog, ir) = _compile_native("from_import_shimmed_stdlib.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , (
        "no native IR for a module whose only import is a shimmed one"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" in layout.functions , (
        "a shimmed module supplies the name natively, so nothing here "
        f"demotes: {sorted(layout.functions)}"
    );
}


test "a property accessor is an owning callable, not a module-fatal site" {
    (prog, ir, coverage) = _compile_with_coverage("from_import_accessor_seam.jac");
    assert not prog.errors_had , (
        f"a `{{ getter; }}` body is a callable the native lane lowers as a "
        f"method, so a violation written there demotes it rather than "
        f"refusing the module: {[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Box.plain" in layout.methods , (
        f"the archetype's ordinary method was lost: {sorted(layout.methods)}"
    );
    seams = [
        s
        for s in _seams_of(coverage, "from_import_accessor_seam.jac")
        if s.startswith("Box.tagged.__get__: ")
    ];
    assert len(seams) == 1 , (
        f"the accessor must be recorded under the name the demotion coverage "
        f"and the seal waivers already use for it, got: {_seams_of(
            coverage, 'from_import_accessor_seam.jac'
        )}"
    );
    assert "collections" in seams[0] , (
        f"the seam reason must name the blocking construct: {seams[0]}"
    );
}


test "a body-scoped from-import demotes only its owning function" {
    (prog, ir, coverage) = _compile_with_coverage("from_import_freefn_seam.jac");
    assert not prog.errors_had , (
        f"a function-owned violation must demote, not fail the module: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"clean sibling function was lost: {sorted(layout.functions)}"
    );
    assert "pyonly" not in layout.functions , (
        "the violating function must be demoted out of the native layout"
    );
    seams = [
        s
        for s in _seams_of(coverage, "from_import_freefn_seam.jac")
        if s.startswith("pyonly: ")
    ];
    assert len(seams) == 1 , (
        f"expected exactly one coverage seam for pyonly, got: {seams}"
    );
    assert "collections" in seams[0] , (
        f"the seam reason must name the blocking construct: {seams[0]}"
    );
}


test "a dataclasses field import is a compile-time declaration" {
    assert _rejected_imports("dataclasses_field_default.jac") == [] , (
        "`field` only ever appears as a has-field default, where the "
        "declaration site consumes it; the native lane never calls it, so "
        "the import belongs in the compile-time vocabulary"
    );
    assert _scan_verdict(_module_with("import from dataclasses { field }")) == "OK" , (
        "the inferred-placement scanner reads the same vocabulary, so a "
        "`field` import must stop demoting the module there too"
    );
}


test "a non-marker dataclasses name still refuses" {
    verdict = _scan_verdict(_module_with("import from dataclasses { dataclass }"));
    assert verdict != "OK" , (
        "the vocabulary is per name: `field` erases at the declaration site "
        f"and `dataclass` does not, so listing it must still refuse: {verdict}"
    );
}


test "a field-defaulted archetype lowers and builds its defaults" {
    (prog, ir) = _compile_native("dataclasses_field_default.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , (
        "no native IR for an archetype whose has-fields default through "
        "`dataclasses.field`"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" in layout.functions , (
        f"the declaration-site marker demoted its module: {sorted(layout.functions)}"
    );
    assert _native_int_fn(ir, "run")() == 13 , (
        "a `default_factory` field must arrive as an empty container of the "
        "declared type and a `default` field as that literal"
    );
}
