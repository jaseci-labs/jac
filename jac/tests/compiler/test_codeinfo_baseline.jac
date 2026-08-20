"""`codeinfo` reaches the native backend, and what still stops short (#8201).

`codeinfo.jac` declares the whole codegen data model -- `CodeGenTarget`,
`InteropManifest`, the native layout records -- and 47 of its has-fields
default through `dataclasses.field(default_factory=...)`. `dataclasses` was
in no native import vocabulary, so a module-scope import with no owning
callable made the module fatally un-lowerable: no IR at all, so nothing that
reads a `CodeGenTarget` field could ever lower either.

`field` is now a compile-time declaration-site marker, the same shape `cast`
and `TypeAlias` already had: admitted per name in `NATIVE_ERASED_IMPORTS`
and erased where it is written, at the has-field default. Four other
module-fatal constructs had to clear with it, since a fatal one hides the
rest: two `object`-typed parameters whose attributes the checker refused, a
`relpath` return that widened to `bytes`, and two `ContextVar` globs whose
inferred type arguments a type-erased generic archetype cannot carry (the
defaults moved to the read sites, which is what CPython's `ContextVar.get`
means anyway).

What this pins is the measured result: `codeinfo` produces IR and every
remaining refusal is a per-callable seam, so the module ships. Each seam is
filesystem, config or Python-codegen machinery, none of it the data model.

**What it does not do, measured rather than assumed.** The nine
`interop_manifest` seams in `boundary_analysis_pass` do not clear yet. They
read `self.ir_in.gen.interop_manifest`, and `UniNode.gen`'s getter imports
`CodeGenTarget` from `codeinfo` at run time; for that call to lower,
`codeinfo` has to be *inferred* native, not merely compilable as a forced
root.

What used to stop that was an accident: `import from typing { Any }` made
`scan_native_blockers` answer `unresolved import 'typing'`. That import is a
hard error in the language now (E1122), so the accident is gone and the hold
is deliberate -- `PLACEMENT_INFERENCE_HELD` names `codeinfo` and says why.

The hold is not bookkeeping. Letting inference through was measured on this
base with the module-fatal glob already fixed, so `codeinfo` does produce IR;
the problem is the blast radius. `unitree`'s closure goes from 11 members to
19 and picks up 21 un-waived seams, and only 13 of those are `codeinfo`'s own
filesystem-and-config machinery. The rest arrive with `passes/uni_pass.jac`
and `passes/transform.jac`, and they include `UniPass.transform`,
`UniPass.traverse` and `UniPass.get_all_sub_nodes` -- pass machinery a parse
reaches, which is exactly the shape that must not ship as an `abort()` stub
inside a sealed artifact. `unitree` is in `NATIVE_SEAL_ROOTS`, so this is a
live seal, not a hypothetical one.

Clearing the hold means answering `codeinfo`'s 13 seams and that closure,
which is wave work; `test_unitree_seal_baseline.jac` is the guard that catches
it either way. This change is deliberately closure-neutral for every sealed
root.

One coverage run, one test, deliberately: see the note in
`test_expr_keys_baseline.jac` on what a file of N tests over one root costs
the 16GB compiler-suite runner.
"""

import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CODEINFO: str = "jac0core/codeinfo.jac";

"""codeinfo's exact native closure, as package-relative paths.

The pass base chain (`transform`, `uni_pass`, `module_codegen_pass`) and
the diagnostics cluster it carries joined when `transform.jac` started
importing `CodeLocInfo` from its declaring module (#8320's re-land) --
the same arrival every pass root's coverage recorded. codeinfo's own seam
set below did not move with it: the thirteen are filesystem, config and
Python-codegen machinery, none of which the base chain touches.
"""
glob CODEINFO_CLOSURE: tuple = (
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

"""codeinfo's own seams: filesystem, config and Python-codegen machinery."""
glob CODEINFO_SEAMS: tuple = (
         "CodeGenTarget.doc_ir.__get__",
         "_func_layout_to_dict",
         "_inferred_native_path",
         "effective_default_codespace",
         "effective_native_closure_cap",
         "install_native_static_init",
         "is_bundled_native_module",
         "is_client_by_location",
         "is_native_by_location",
         "native_layout_to_dict",
         "native_stdlib_root",
         "native_wasm_stem",
         "resolve_native_module"
     );

"""Compile one root the way seal_native_artifacts does, up to the coverage."""
def _root_coverage(rel: str) -> tuple {
    if native_artifact_for("jaclang." + rel[:-4].replace("/", ".")) is not None {
        testskip(
            f"{rel} is served from this runtime's native seal; the coverage "
            "gated the build via seal_demotion_report"
        );
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
    return (coverage, has_ir, errors, );
}

"""The seam names one closure member reported, sorted."""
def _seam_names(coverage: dict, member: str) -> tuple {
    names: list[str] = [];
    for (path, rec) in coverage.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where != member {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, _why) = str(seam).partition(": ");
            names.append(name if sep else str(seam));
        }
    }
    return tuple(sorted(names));
}


test "codeinfo produces native IR, and every refusal left is a seam" {
    (coverage, has_ir, errors) = _root_coverage(CODEINFO);
    assert not errors , (
        "codeinfo must reach the backend with nothing fatal left; a "
        f"module-scope refusal hides every other one: {errors[:5]}"
    );
    assert has_ir , (
        "no LLVM IR for codeinfo -- the compile aborted before codegen, so "
        "a zero-error coverage would mean 'not reached', not 'clean'"
    );

    seen_closure = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
            for p in coverage
        )
    );
    assert seen_closure == CODEINFO_CLOSURE , (
        f"codeinfo's native closure changed: {seen_closure} != {CODEINFO_CLOSURE}"
    );

    seen_seams = _seam_names(coverage, CODEINFO);
    assert seen_seams == CODEINFO_SEAMS , (
        "codeinfo's seam set moved. A new name means the data model grew a "
        "refusal the backend cannot lower; a missing one means a seam "
        f"cleared and this table should shrink: {seen_seams} != {CODEINFO_SEAMS}"
    );

    for text in [*errors, *seen_seams] {
        assert "dataclasses" not in text , (
            "`dataclasses.field` is a compile-time declaration the has-field "
            f"default consumes; nothing may refuse it again: {text}"
        );
    }
}
