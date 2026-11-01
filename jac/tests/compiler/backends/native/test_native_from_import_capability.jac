"""A `from`-import item is classified by the capability gate, like a bare import.

The capability gate walked an import statement's items and asked
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
-- so the partition answers for it rather than falling through to a module
refusal.
"""

import ctypes;
import os;
import re;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.placement.placement { scan_native_blockers }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support {
    TESTS_DIR,
    compile_mir,
    compile_native,
    diagnostics_text,
    error_codes,
    kernel_compile_file,
    native_address,
    source_spelled,
    unit_symbol
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );


"""Forced-native compile options."""
def _opts -> CompileOptions {
    return CompileOptions(force_codespace='native');
}


"""Compile a fixture on the native pathway; return the kernel's result."""
def _compile_native(fixture: str) -> any {
    return kernel_compile_file(os.path.join(FIXTURES, fixture), _opts());
}


"""The `Python module import` names the capability gate rejects for a fixture."""
def _rejected_imports(fixture: str) -> list[str] {
    result = _compile_native(fixture);
    found: list[str] = [];
    for error in result.errors {
        found.extend(re.findall(r"Python module import '([^']+)'", error.message));
    }
    return found;
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


"""A JIT-resolved `int()` function from a compiled fixture's engine."""
def _native_int_fn(eng: any, name: str) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}


test "a from-imported Python base is classified, not waved through" {
    assert _rejected_imports("from_import_retained_base.jac") == ["threading"] , (
        "the capability gate read the `from` import's items and found no "
        "module to classify, so an unlowerable Python base reached codegen "
        "unchallenged"
    );
}


test "the from-imported Python base refuses instead of lowering" {
    result = _compile_native("from_import_retained_base.jac");
    assert "E5090" in error_codes(result) , (
        "a module-scope Python `from` import has no owning callable to "
        f"absorb it, so it must keep the whole-module refusal, got:\n"
        f"{diagnostics_text(result)}"
    );
    assert any("threading" in error.message for error in result.errors) , (
        f"the diagnostic must name the module it refuses:\n{diagnostics_text(result)}"
    );
    assert not any(unit.native_ir for unit in result.units) , (
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
    (eng, fx) = compile_native("typing_type_alias_glob.jac");
    assert fx.llvm_ir() , "no native IR for the TypeAlias glob";
    assert _native_int_fn(eng, "run")() == 8 , (
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
    for _ in range(2) {
        (eng, fx) = compile_native("classvar_marker_consumer.jac");
        assert fx.llvm_ir() , (
            "no native IR for a module whose dependency's only compile-time "
            "import is `ClassVar`"
        );
        members = sorted({os.path.basename(p) for p in fx.unit.native_deps});
        assert "classvar_marker_dep.jac" in members , (
            f"the dependency has to be in the consumer's native closure, not "
            f"refused at placement and left to Python: {members}"
        );
        assert _native_int_fn(eng, "run")() == 42 , (
            "the linked dependency has to answer across the native edge"
        );
    }
}


test "a from import of an na_stdlib-shimmed module lowers" {
    assert _rejected_imports("from_import_shimmed_stdlib.jac") == [] , (
        "`keyword` ships as Jac source under `runtime/na_stdlib`, so a "
        "native unit supplies the name the import binds; classifying "
        "`from`-import items must not read a shimmed module as Python"
    );
    (eng, fx) = compile_native("from_import_shimmed_stdlib.jac");
    assert fx.llvm_ir() , (
        "no native IR for a module whose only import is a shimmed one"
    );
    assert unit_symbol(fx, "run") not in fx.iface().demoted , (
        "a shimmed module supplies the name natively, so nothing here "
        f"demotes: {fx.iface().demoted}"
    );
}


test "a property accessor is an owning callable, not a module-fatal site" {
    fx = compile_mir("from_import_accessor_seam.jac");
    demoted = {source_spelled(sym): reason for (sym, reason) in fx.demoted().items()};
    assert not any(sym.endswith(".Box.plain") for sym in demoted) , (
        f"the archetype's ordinary method was lost: {demoted}"
    );
    accessor = [
        reason
        for (sym, reason) in demoted.items()
        if ".Box.tagged." in sym or sym.endswith(".Box.tagged")
    ];
    assert len(accessor) == 1 , (
        f"a `{{ getter; }}` body is a callable the native lane lowers as a "
        f"method, so a violation written there demotes it rather than "
        f"refusing the module; got: {demoted}"
    );
    assert "collections" in accessor[0] , (
        f"the demotion reason must name the blocking construct: {accessor[0]}"
    );
}


test "a body-scoped from-import demotes only its owning function" {
    fx = compile_mir("from_import_freefn_seam.jac");
    assert not fx.is_demoted("clean") , f"clean sibling function was lost: {fx.demoted()}";
    assert fx.is_demoted("pyonly") , (
        f"the violating function must be demoted: {fx.demoted()}"
    );
    assert "collections" in fx.reason("pyonly") , (
        f"the demotion reason must name the blocking construct: {fx.reason('pyonly')}"
    );
}


test "a Jac field import is a compile-time declaration" {
    assert _rejected_imports("object_field_default.jac") == [] , (
        "`ObjectField` only ever appears as a has-field default, where the "
        "declaration site consumes it; the native lane never calls it, so "
        "the import belongs in the compile-time vocabulary"
    );
    assert _scan_verdict(
        _module_with("import from jaclang.runtime.object_model { ObjectField }")
    )
        == "OK" , (
        "the inferred-placement scanner reads the same vocabulary, so a "
        "`ObjectField` import must stop demoting the module there too"
    );
}


test "a Python dataclass decorator still refuses" {
    verdict = _scan_verdict(_module_with("import from dataclasses { dataclass }"));
    assert verdict != "OK" , (
        "the vocabulary is per name: `ObjectField` erases at the declaration site "
        f"and `dataclass` does not, so listing it must still refuse: {verdict}"
    );
}


test "a field-defaulted archetype lowers and builds its defaults" {
    (eng, fx) = compile_native("object_field_default.jac");
    assert fx.llvm_ir() , (
        "no native IR for an archetype whose has-fields default through "
        "`jaclang.runtime.object_model.ObjectField`"
    );
    assert unit_symbol(fx, "run") not in fx.iface().demoted , (
        f"the declaration-site marker demoted its module: {fx.iface().demoted}"
    );
    assert _native_int_fn(eng, "run")() == 13 , (
        "a `default_factory` field must arrive as an empty container of the "
        "declared type and a `default` field as that literal"
    );
}
