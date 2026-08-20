"""Sealing wave 6: capability_check_pass reaches IR, and what the last five seams are.

Same harness as waves 1, 2, 4 and 5 -- `na_coverage_begin` plus
`force_codespace='native'`, exactly what `seal_native_artifacts` runs -- and
the same two-way discipline: this file fails if the closure gains a member,
if IR stops being produced, or if the seam set moves in either direction.

`capability_check_pass` is not sealed here. It is measured, and the
measurement is the deliverable: wave 5 recorded it as "no IR, 7 blocking
errors, 7 own seams behind them", and every one of those seven errors is
gone. The pass produces native IR for the first time, and the seams behind
that wall are now countable rather than hypothetical.

What cleared, and how:

  - Two bare `tuple` return annotations got their element types.
    #8203 landed static tuple *fields*; a bare `tuple` return still erases,
    and it erased the violation list, its partition, and the `.values()` walk
    over the demotable map along with them.
  - `String.lit_value` is `str | bytes`, so the three f-string spec readers
    narrow to `str` and refuse a bytes spec rather than returning one through
    a `str | None` signature.
  - `item.path` is None-checked before `len()`, and the JS-method walk
    narrows its parent through `isinstance` instead of through a bool it
    stored first.
  - `isinstance(nd, NATIVE_REJECT_NODES)` narrowed the node to *the table's
    own tuple type*, which is a wrong narrow rather than a missing one. The
    checker reads a named tuple of classes as the alternatives it holds now;
    that fix is `test_isinstance_tuple_glob.jac`.

And the two own seams that cleared with it: the fatal-violation report is
typed through its `list()` copy so the emit arguments are not Unknown, the
emit splits on the optional help text because an optional cannot cross the
Python-base boundary `Transform.emit` sits behind, and the two
`viols_reported` flags moved off `UniNode.gen` onto `Module` -- `gen`'s
getter is a standing seam, so every read behind it was one too.

## The four that remain, and what each one waits on

All four are one fact seen from different distances:
`jac0core/codeinfo.jac` is not in the closure. `scan_native_blockers`
refuses it for `import from typing { Any }`, and
`test_native_erased_any.jac` carries that measurement and its clearing
list. `classify_native_import` reads codeinfo's compile-time import
table, `base_expr_is_erased` reads its erased-base table,
`name_in_type_position` is a pure cascade of the second, and
`native_capability_violations` cascades on the first and third -- plus
one member gap of its own, `os.path.abspath`, which clears when that
member lowers.

The fifth is gone. `ClientCapabilityCheckPass.transform` waited on the
pass-tier boundary -- `client_capability_violations` lives in
`module_codegen_pass` -- and #8320's re-land put the base chain in this
closure (the honest `CodeLocInfo` import), so the callee linked and the
seam cleared. The same link took the `iter_context_stmts` half out of
`native_capability_violations`' causes.

This file still pins `module_codegen_pass`'s zero own seams below: it is
the half of the wave's work that capability's coverage cannot see.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CAPABILITY: str = "compiler/passes/main/capability_check_pass.jac",
     MODULE_CODEGEN: str = "jac0core/passes/module_codegen_pass.jac";

"""capability_check_pass's exact native closure, as package-relative paths.

The pass base chain joined this closure when `transform.jac` started
importing `CodeLocInfo` from its declaring module (#8320's re-land):
`transform`, `uni_pass` and `module_codegen_pass` link in, and
`diagnostic_utils` and the logging shim ride with them. That is the
crossing the old pin's help text predicted -- and it collected the
predicted payout below.
"""
glob CAPABILITY_CLOSURE: tuple = (
         "compiler/passes/main/capability_check_pass.jac",
         "compiler/type_registry.jac",
         "compiler/type_system/type_utils.jac",
         "compiler/type_system/types.jac",
         "jac0core/constant.jac",
         "jac0core/diagnostic_utils.jac",
         "jac0core/diagnostics.jac",
         "jac0core/helpers.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/transform.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/logging.jac",
         "runtimelib/na_stdlib/pathlib.jac"
     );

"""capability's own four, each mapped to the mechanism that clears it.

This table held five until the base chain linked.
`ClientCapabilityCheckPass.transform` was waiting on exactly that
crossing -- `client_capability_violations` lives in `module_codegen_pass`
-- and it cleared the moment the callee joined the closure.
`native_capability_violations` stays, but its reasons moved: the
`iter_context_stmts` half of its old cause cleared with the same link,
and what remains is its codeinfo cascades plus an `os.path.abspath`
member the native lane does not carry yet.
"""
glob CAPABILITY_SEAMS: dict[(str, str)] = {
         "classify_native_import": "codeinfo not in closure: reads native_erased_import_names",
         "base_expr_is_erased": "codeinfo not in closure: reads NATIVE_ERASED_BASES",
         "name_in_type_position": "cascade of base_expr_is_erased",
         "native_capability_violations": "codeinfo cascades (classify_native_import, name_in_type_position) plus os.path.abspath"
     };

glob _COVERAGE_MEMO: dict[(str, tuple)] = {};

"""A root's dotted module name, for the sealed-runtime skip gate."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Compile one root the way seal_native_artifacts does, up to the coverage."""
def _root_coverage(rel: str) -> tuple {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image; a source coverage here "
            "measures the image's trust boundary, not the unit's own seams"
        );
    }
    if native_artifact_for(_root_module_name(rel)) is not None {
        testskip(
            f"{rel} is served from this runtime's native seal; the coverage "
            "gated the build via seal_demotion_report"
        );
    }
    if rel in _COVERAGE_MEMO {
        return _COVERAGE_MEMO[rel];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(PKG_PATH / rel),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    result = (coverage, has_ir, errors, );
    _COVERAGE_MEMO[rel] = result;
    return result;
}

"""The bare seam names a given closure member contributes."""
def _own_seams(rel: str, member: str) -> set {
    (coverage, _has_ir, _errors) = _root_coverage(rel);
    found: set = set();
    for (path, rec) in coverage.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where != member {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, _why) = str(seam).partition(": ");
            found.add(name if sep else str(seam));
        }
    }
    return found;
}


test "capability_check_pass compiles with no module-level errors" {
    (_coverage, _has_ir, errors) = _root_coverage(CAPABILITY);
    assert not errors , (
        "capability_check_pass had seven module-level errors before this "
        f"wave and must keep zero; got {len(errors)}: {errors[:5]}"
    );
}


test "capability_check_pass produces native IR" {
    (_coverage, has_ir, _errors) = _root_coverage(CAPABILITY);
    assert has_ir , (
        "no LLVM IR for capability_check_pass -- the compile aborted before "
        "codegen, so a seam count below would mean 'not reached', not "
        "'measured'"
    );
}


test "capability_check_pass's native closure is exactly the measured set" {
    (coverage, _has_ir, _errors) = _root_coverage(CAPABILITY);
    seen = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
            for p in coverage
        )
    );
    assert seen == CAPABILITY_CLOSURE , (
        f"closure changed: {seen} != {CAPABILITY_CLOSURE}. If "
        "module_codegen_pass or codeinfo joined, two or three of the seams "
        "below should have cleared with it -- update both together"
    );
}


test "capability_check_pass's own seams are exactly the five named" {
    seen = _own_seams(CAPABILITY, CAPABILITY);
    expected = set(CAPABILITY_SEAMS.keys());
    assert seen == expected , (
        "capability_check_pass's own seam set moved.\n"
        + f"  gained: {sorted(seen - expected)}\n"
        + f"  lost:   {sorted(expected - seen)}\n"
        + "Each remaining seam names its clearing mechanism in "
        + "CAPABILITY_SEAMS; a loss means one landed and this table plus the "
        + "module docstring have to say so."
    );
}


test "module_codegen_pass carries no seams of its own" {
    # The half of this wave that capability's coverage cannot see. All six of
    # its former seams -- iter_context_stmts and the five cascades of it --
    # cleared when iter_woven_segments stopped erasing the statement type.
    # `_MODULE_CODEGEN_SEAM_WAIVERS` survives for exactly one other root:
    # on `uni_pass.jac`, the only unit that links this pass without the
    # unitree layout, the family still demotes and is waived there. On its
    # own root -- what this test measures -- the count is zero.
    seen = _own_seams(MODULE_CODEGEN, MODULE_CODEGEN);
    assert not seen , (
        f"module_codegen_pass demotes again: {sorted(seen)}. It reached zero "
        "own seams in this wave and its waiver tuple was deleted"
    );
}


test "module_codegen_pass compiles clean and produces IR" {
    (_coverage, has_ir, errors) = _root_coverage(MODULE_CODEGEN);
    assert not errors , f"module_codegen_pass errors: {errors[:5]}";
    assert has_ir , "no LLVM IR for module_codegen_pass";
}
