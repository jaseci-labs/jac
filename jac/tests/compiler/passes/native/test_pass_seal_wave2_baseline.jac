"""Sealing wave 2: three more compiler passes join the native seal.

Same discipline as `test_pass_seal_wave1_baseline.jac`: each root is
measured exactly the way `seal_native_artifacts` measures it, and three
things are pinned per root -- exact closure membership, native IR
production, and the seam set two-way against
`NATIVE_SEAL_DEMOTION_WAIVERS`.

The wave-2 roots and what cleared them:

  - `sem_def_match_pass` was wave 1's stop-the-line refusal: its live
    `connect_sems` dispatches `Token.lit_value` through the vtable, and
    the `String`/`MultiString` decoders were eval-bound stubs. #8251 made
    jac decode its own string literals, the decoders lower, and the
    refusal pin in `test_sealed_seam_reachability.jac` fired exactly as
    designed. Zero own seams.
  - `ast_validation_pass` reached zero own seams through typed
    accumulators and type-driven rewrites (`_scope_declares_state` and
    `_returns_jsx` take the `(Ability | ImplDef)` the caller guarantees
    instead of probing dynamic attributes; the jsx-slot helpers take
    `list[UniNode]`).
  - `semantic_analysis_pass`: the inherited forwarding static gave way to
    the direct `UniNode.get_all_sub_nodes` call, and typed accumulators
    cleared the rest. One waiver remains.

The one remaining waiver: `Transform.ice` raises through Python
diagnostics machinery, and `SemanticAnalysisPass.enter_has_var` (its one
caller here) is a visitor method the Python traversal dispatches into,
never called natively inside the artifact; the layout registration routes
its Python callers to bytecode. It clears when `ice` construction lowers
or when the internal-error guard moves behind the emit-as-data path.

Measured and REFUSED in wave 2; the named preps have since landed:

  - `sym_tab_build_pass`: CLEARED. The wave-2 refusal was a real abort
    path -- live `exit_module_path` read `Import.is_jac`, chaining into
    `__jac_detected` and `ModulePath.resolve_relative_path`, the waived
    filesystem import-resolution family. Import detection is
    driver-stamped data now (`Import.jac_detected`, stamped by
    `resolve_absorb_imports` alongside `absorbed_mod`, the #8242
    pattern) and the pass consumes the slot. Coverage: one waiver-class
    seam (`exit_global_vars` calls `Transform.ice`, the
    `semantic_analysis` waiver's twin). Seal-ready; the cleared-state
    pin lives in `test_sealed_seam_reachability.jac`.
  - `decl_impl_match_pass`: CLEARED. The `id()`-keyed dedup lowered on
    its own once #8212 landed; the remaining preps were the typed
    `NameAtom` link accumulators, the inlined annex-suffix facts
    replacing the function-local `ext_registry` import, a typed dedup
    reset, and moving the symbol-binding free functions
    (`bind_assignment_targets` and friends) into `unitree`, whose
    vocabulary they read. Coverage: zero own seams, native IR produced.
    Seal-ready.
  - `boundary_analysis_pass`: driver coupling GONE, manifest vocabulary
    remains. The driver now precomputes every filesystem, config and
    program-state question an import raises and stamps
    `Import.boundary_facts` before the pass runs (`stamp_boundary_facts`
    in `run_schedule`); `JacCompiler` construction, file reads, native
    module resolution and `prog` reads left the pass entirely, and its
    closure dropped `helpers`/`fnmatch`. Remaining seams are one
    coherent family plus one shim gap: methods that write the
    `InteropManifest` demote because `codeinfo.jac` cannot emit native
    IR yet (its module-level `dataclasses` import is a fatal placement
    violation), and `_native_source_module_of` needs `os.path.relpath`
    in the na_stdlib shim. It seals when codeinfo lowers (or the
    manifest goes data, the #8243 family) -- not this wave.

The measurement is a source-lane one: under a sealed jaclang image the
coverage reads the image's trust boundary instead of each unit's own
coupling, so `_root_coverage` skips there (both gates below).
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     WAVE2_ROOTS: tuple = (
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac"
     );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE2_CLOSURES: dict[(str, tuple)] = {
         "jac0core/passes/ast_validation_pass.jac": (
             "compiler/type_registry.jac",
             "compiler/type_system/type_utils.jac",
             "compiler/type_system/types.jac",
             "jac0core/codeinfo.jac",
             "jac0core/constant.jac",
             "jac0core/diagnostic_utils.jac",
             "jac0core/diagnostics.jac",
             "jac0core/helpers.jac",
             "jac0core/passes/ast_validation_pass.jac",
             "jac0core/passes/module_codegen_pass.jac",
             "jac0core/passes/transform.jac",
             "jac0core/passes/uni_pass.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac",
             "runtimelib/na_stdlib/_hashlib_native.jac",
             "runtimelib/na_stdlib/contextvars.jac",
             "runtimelib/na_stdlib/fnmatch.jac",
             "runtimelib/na_stdlib/hashlib.jac",
             "runtimelib/na_stdlib/keyword.jac",
             "runtimelib/na_stdlib/logging.jac",
             "runtimelib/na_stdlib/pathlib.jac"
         ),
         "jac0core/passes/semantic_analysis_pass.jac": (
             "compiler/type_registry.jac",
             "compiler/type_system/type_utils.jac",
             "compiler/type_system/types.jac",
             "jac0core/codeinfo.jac",
             "jac0core/constant.jac",
             "jac0core/diagnostic_utils.jac",
             "jac0core/diagnostics.jac",
             "jac0core/helpers.jac",
             "jac0core/passes/module_codegen_pass.jac",
             "jac0core/passes/semantic_analysis_pass.jac",
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
         ),
         "compiler/passes/main/sem_def_match_pass.jac": (
             "compiler/passes/main/sem_def_match_pass.jac",
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
         )
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

"""Coverage seams as `<pkg-rel module>::<Type>.<method>` -> reason."""
def _seams_by_key(rel: str) -> dict[(str, str)] {
    (coverage, _has_ir, _errors) = _root_coverage(rel);
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(coverage.items()) {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        for seam in (rec["seams"] or []) {
            (name, sep, why) = str(seam).partition(": ");
            found[f"{where}::{name if sep else str(seam)}"] = why if sep else "";
        }
        if rec["outcome"] == "demoted" {
            found[f"{where}::<module>"] = f"[{rec['code']}] {rec['detail']}";
        }
    }
    return found;
}


test "every wave-2 root is registered for the seal" {
    for rel in WAVE2_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate "
            "nothing at seal time"
        );
        for member in WAVE2_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-2 root's native closure is exactly the measured set" {
    for rel in WAVE2_ROOTS {
        (coverage, _has_ir, errors) = _root_coverage(rel);
        assert not errors , (
            f"{rel} compile errors (closure below is 'not reached', not "
            f"'clean'): {errors[:5]}"
        );
        seen = tuple(
            sorted(
                Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
                for p in coverage
            )
        );
        assert seen == WAVE2_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE2_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-2 root's closure produces native IR" {
    for rel in WAVE2_ROOTS {
        (_coverage, has_ir, _errors) = _root_coverage(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam coverage would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-2 closure" {
    for rel in WAVE2_ROOTS {
        seams = _seams_by_key(rel);
        (allowed, _bare) = seal_waiver_names(rel);
        unexpected = sorted(
            k
            for k in seams
            if k not in allowed
        );
        assert not unexpected , (
            f"{len(unexpected)} un-waived seam(s) in {rel}'s sealed closure:\n"
            + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
        );
    }
}


test "every wave-2 seam waiver still matches a real seam" {
    for rel in WAVE2_ROOTS {
        seams = _seams_by_key(rel);
        (allowed, _bare) = seal_waiver_names(rel);
        stale = sorted(
            k
            for k in allowed
            if k not in seams
        );
        assert not stale , (
            f"{rel} waives seams that no longer demote -- drop them:\n"
            + "\n".join(f"  {k}" for k in stale)
        );
    }
}
