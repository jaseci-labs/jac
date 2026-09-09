"""Type-position constructs erase natively instead of blocking a module.

Three spellings the compiler's own passes use are directives to a type
checker, not values a program computes: `typing.cast(T, x)`, a module-scope
`glob T = TypeVar(...)`, and an `abc.ABC` base. Each one used to demote the
module that wrote it, and through the import closure most of the pass tree
with it.

The shared cure is that the native module-import gate asks whether a Python
name is *used at run time*. An annotation is not a run-time use, and neither
is a base the native lane erases: nothing loads it, and `LayoutPass` drops it
from the hierarchy before a layout is built. `name_in_type_position` therefore
covers erased base-class expressions alongside annotations and return types.

The boundary is drawn at *erased*, not at *base*, and two negative tests hold
it there. A base the native lane keeps is a run-time dependency -- an
archetype cannot mean what it says without it, and no native unit can supply
it -- so it still refuses, as does a name the unit would have to call. Widening
to base classes wholesale would have traded those refusals for a class that
silently loses everything it inherited.

On top of that gate sit the three erasures. `cast` lowers to its second
argument, which is what `typing.cast` returns in Python too, so the lanes
agree by construction. A `TypeVar` glob is skipped by native glob lowering as
a compile-time declaration (`ModuleFacts.is_erased_type_decl`). An
`ABC` base leaves the native parent list entirely, so an archetype whose only
base is the marker keeps a bare layout with no vtable slot -- Jac's own `abst`
keyword is what carries abstractness natively.

The keyword-forms contract is untouched: `abstractmethod`, `ABCMeta` and a
bare `import abc` still refuse, pinned in `test_native_abc_erasure`.
"""

import ctypes;
import importlib;
import os;
import sys;
import from jaclang.compiler.passes.capability_check_pass {
    native_capability_violations
}
import from jaclang.compiler.passes.layout_pass { get_layout_registry }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.placement.placement { scan_native_blockers }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );


"""Forced-native options that skip the IR cache."""
def _opts -> CompileOptions {
    return CompileOptions(
        force_codespace='native', force_target_program=True, no_ir_cache=True
    );
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir, );
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
        src, os.path.join(FIXTURES, "type_position_probe.jac"), prog=JacProgram()
    );
    assert not had_err , f"fixture source did not parse: {src!r}";
    (reason, _deps) = scan_native_blockers(mod, FIXTURES, allow_pub=True);
    return reason or "OK";
}


"""Wrap an import line in a module the scanner accepts apart from the import."""
def _module_with(import_line: str) -> str {
    return import_line + "\n\nwith entry {\n    print(1);\n}\n";
}


"""A JIT-resolved `int()` function from a compiled fixture."""
def _native_int_fn(ir: any, name: str) -> any {
    eng = ir.gen.native_engine;
    assert eng is not None , f"no native engine for '{name}'";
    addr = eng.get_function_address(name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}


"""Run a fixture's zero-argument function through the plain Python lane."""
def _run_py_lane(fixture_stem: str, func_name: str) -> any {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        mod = importlib.import_module(fixture_stem);
        return getattr(mod, func_name)();
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop(fixture_stem, None);
    }
}


test "a typing.cast import no longer blocks native placement" {
    assert _scan_verdict(_module_with("import from typing { cast }")) == "OK" , (
        "`import from typing { cast }` still demotes the module, so every "
        "import closure reaching it stays demoted too"
    );
}


test "typing.cast lowers with no seam" {
    (prog, ir) = _compile_native("typing_cast_identity.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    for fn in ["run", "widen"] {
        assert fn in layout.functions , (
            f"'{fn}' was demoted to a Python seam rather than erasing the "
            f"cast: {sorted(layout.functions)}"
        );
    }
}


test "typing.cast is the identity on both lanes" {
    (prog, ir) = _compile_native("typing_cast_identity.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    native = _native_int_fn(ir, "run")();
    assert native == 21 , f"native cast chain returned {native}, expected 21";
    assert _run_py_lane("typing_cast_identity", "run") == native , (
        "the native erasure and `typing.cast` disagree; `cast` returns its "
        "second argument unchanged in Python, so the lanes must match"
    );
}


test "the cast erasure reaches an annexed impl body" {
    (prog, ir) = _compile_native("typing_cast_annex.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" in layout.functions , (
        f"the annexed function demoted rather than erasing its cast: "
        f"{sorted(layout.functions)}"
    );
    assert "Box.doubled" in layout.methods , (
        f"the annexed method demoted rather than erasing its cast: "
        f"{sorted(layout.methods)}"
    );
    assert _native_int_fn(ir, "run")() == 12 , (
        "the annexed bodies stopped computing what they compute in Python"
    );
}


test "a TypeVar import no longer blocks native placement" {
    assert _scan_verdict(_module_with("import from typing { TypeVar }")) == "OK" , (
        "`import from typing { TypeVar }` still demotes the module; the "
        "generic parameter it binds is erased at every use site already"
    );
}


test "a module-scope TypeVar glob produces native IR" {
    (prog, ir) = _compile_native("typing_typevar_glob.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the TypeVar glob";
    assert _native_int_fn(ir, "run")() == 9 , (
        "the TypeVar glob changed what the rest of the module computes"
    );
}


test "an erased base is a type position, not a run-time use" {
    assert _rejected_imports("type_position_base_marker.jac") == [] , (
        "a Python name mentioned only as a base the native lane erases was "
        "read as a run-time use; nothing loads that base at run time"
    );
}


test "a base the native lane keeps still refuses" {
    assert _rejected_imports("type_position_retained_base.jac") == ["threading"] , (
        "an ordinary Python base is a run-time dependency: the archetype "
        "cannot mean what it says without it, and a native unit cannot "
        "supply it. Only an erased base is free"
    );
}


test "a run-time use of a Python module still refuses" {
    assert _rejected_imports("type_position_runtime_use.jac") == ["threading"] , (
        "widening the gate to compile-time positions must not accept a name "
        "the native unit would have to call"
    );
}


test "an ABC base leaves the native parent list" {
    (prog, ir) = _compile_native("abc_marker_base.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    reg = get_layout_registry(ir, prog);
    assert "ABC" not in reg.class_parents.get("Shape", []) , (
        f"the erased marker is still a native parent of Shape: "
        f"{reg.class_parents.get('Shape')}"
    );
    assert "ABC" not in reg.mro_order.get("Shape", []) , (
        f"the erased marker is still on Shape's native MRO: "
        f"{reg.mro_order.get('Shape')}"
    );
}


test "a marker-only base costs the archetype no vtable slot" {
    (prog, ir) = _compile_native("type_position_base_marker.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    reg = get_layout_registry(ir, prog);
    layout = reg.get_layout("Marked");
    assert layout is not None , "Marked has no native layout";
    assert layout.vtable_ptr_slot is None , (
        "the marker base forced a vtable pointer onto every instance of "
        "Marked; an erased base leaves nothing to dispatch through"
    );
    assert _native_int_fn(ir, "run")() == 7 , (
        "the archetype stopped reading its own field once the base erased"
    );
}


test "the erased base keeps Python-lane abstractness" {
    raised = "";
    try {
        _run_py_lane("abc_marker_base", "run");
    } except Exception as _e {
        raised = f"{type(_e).__name__}: {_e}";
    }
    assert raised == "" , (
        f"the concrete subclass stopped running on the Python lane: {raised}"
    );
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop("abc_marker_base", None);
        mod = importlib.import_module("abc_marker_base");
        abstract_error = "";
        try {
            mod.Shape();
        } except TypeError as _te {
            abstract_error = str(_te);
        }
        assert abstract_error , (
            "instantiating the abstract base stopped raising on the Python "
            "lane; the native erasure must not reach the Python emission, "
            "which still carries the `ABC` base and `@abstractmethod`"
        );
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop("abc_marker_base", None);
    }
}
