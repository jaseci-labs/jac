"""Sealing wave 6: capability_check_pass reaches IR, and what the last seam is.

Same harness as waves 1, 2, 4 and 5 -- `na_coverage_begin` plus
`force_codespace='native'`, exactly what `seal_native_artifacts` runs -- and
the same two-way discipline: this file fails if the closure gains a member,
if IR stops being produced, or if the seam set moves in either direction.

`capability_check_pass` was measured here first, taken to one seam by B4
(#8323), and then REFUSED for the seal by the seal's own strongest check:
wave 5 recorded it as "no IR, 7 blocking errors, 7 own seams behind
them", this wave cleared every error and counted five seams, emptying
`PLACEMENT_INFERENCE_HELD` cleared four of the five -- and the pooled
seal's abort-stub linkage check then read the IR that ships and found
`NativeCapabilityCheckPass.transform`, the root's live entry point,
linking the one remaining seam's stub directly. A waiver cannot excuse a
stub the live surface calls, so the root sits in
`NATIVE_SEAL_REFUSED_ROOTS` with that finding as its named blocker, and
the accounting below keeps the refused root measured.

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

## The one that remains, and what it waits on

Four of the recorded five cleared when B4 (#8323) emptied
`PLACEMENT_INFERENCE_HELD` and `codeinfo` -- with `transform`,
`uni_pass` and `module_codegen_pass` riding the same admissibility flip
-- joined this closure. `classify_native_import` reads codeinfo's
compile-time import table and `base_expr_is_erased` its erased-base
table, both in-unit now; `name_in_type_position` was a pure cascade of
the second; and `ClientCapabilityCheckPass.transform` calls
`client_capability_violations`, a module-level *function* of
`module_codegen_pass`, which inlines once the module is a member.

The one left is `native_capability_violations`, and it is the pass-tier
method boundary this file described: it calls
`ModuleCodegenPass.iter_context_stmts`, a *method* on another sealed
root's class, and that crossing clears when the artifacts link, not when
the callee is fixed -- the callee has been fixed since this wave landed.

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
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_REFUSED_ROOTS,
    NATIVE_SEAL_ROOTS
}

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
         "jac0core/codeinfo.jac",
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
         "runtimelib/na_stdlib/contextvars.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/logging.jac",
         "runtimelib/na_stdlib/pathlib.jac"
     );

"""capability's own seams, each mapped to the mechanism that clears it.

Four of the five cleared the moment B4 emptied
`PLACEMENT_INFERENCE_HELD` and `codeinfo`, `transform`,
`module_codegen_pass` and the rest of the pass spine joined this
closure: `classify_native_import` and `base_expr_is_erased` read
`codeinfo`'s tables in-unit now, `name_in_type_position` cascaded on the
second, and `ClientCapabilityCheckPass.transform` calls
`client_capability_violations` as an in-unit function. The one left is
the pass-tier method crossing, exactly as this file predicted.
"""
glob CAPABILITY_SEAMS: dict[(str, str)] = {
         "native_capability_violations": "pass-tier crossing: calls ModuleCodegenPass.iter_context_stmts"
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


test "capability_check_pass is refused for the seal, by name" {
    assert CAPABILITY not in NATIVE_SEAL_ROOTS , (
        f"{CAPABILITY} is in NATIVE_SEAL_ROOTS. The seal's abort-stub "
        "linkage check refused it -- NativeCapabilityCheckPass.transform "
        "links the native_capability_violations stub -- so re-rooting it "
        "needs that finding cleared first, not just this assertion flipped"
    );
    blocker = NATIVE_SEAL_REFUSED_ROOTS.get(CAPABILITY, "");
    assert "NativeCapabilityCheckPass" in blocker , (
        f"{CAPABILITY} is not in NATIVE_SEAL_REFUSED_ROOTS with its "
        f"measured blocker; a refusal without its name rots: {blocker!r}"
    );
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


test "capability_check_pass's own seams are exactly the named set" {
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
