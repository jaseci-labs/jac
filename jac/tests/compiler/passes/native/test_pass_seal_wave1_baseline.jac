"""Sealing wave 1: four compiler passes join the native seal.

Each root below is measured exactly the way `seal_native_artifacts`
measures it (same `CompileOptions`, same coverage), and three things are
pinned per root, the same discipline `test_unitree_seal_baseline.jac` set:

  1. **Closure membership** is exact. Every root drags `constant`,
     `srcloc` and `unitree` into its native unit -- and, since B4 (#8323)
     emptied `PLACEMENT_INFERENCE_HELD`, the pass spine with them:
     `codeinfo`'s admissibility flipped `native_default_path_ok` for
     `transform`, `uni_pass` and `module_codegen_pass`, so the base
     chain that deliberately stayed Python-side is in-unit now, plus the
     `diagnostics` / `diagnostic_utils` / `contextvars` / `logging`
     leaves it drags. A new member beyond these means a module-level
     import changed and has to reach zero un-waived seams before the
     root can keep sealing.
  2. **The root produces native IR.** A zero-seam census without IR means
     "not reached", not "clean".
  3. **The seam set matches `NATIVE_SEAL_DEMOTION_WAIVERS` two-way.** An
     un-waived seam fails (it would ship as an `abort()` stub), and a
     waiver that stops matching a real seam fails too, so the table can
     only shrink honestly.

Every waiver names what blocks it and what clears it:

  - `unitree`'s fifteen seams recur in every closure and are documented in
    `test_unitree_seal_baseline.jac`; each pass root's waiver tuple extends
    `_UNITREE_SEAM_WAIVERS` rather than restating them.
  - `EndpointEffectPass.enter_ability` / `.enter_archetype` wrote
    endpoint classifications through `UniNode.gen`, Python-only while
    the lazy `CodeGenTarget` construction could not lower. They cleared
    when `codeinfo` joined every closure (B4) and `.gen` lowered with
    it -- the same mechanism that cleared unitree's
    `UniNode.gen.__get__` waiver.
  - `module_codegen_pass` used to waive six, led by
    `ModuleCodegenPass.iter_context_stmts` running `isinstance` over an
    element-erased sequence element, with the other five as pure call
    cascades of it. The clearing mechanism recorded here was "when the
    native backend lowers `isinstance` over erased operands"; what
    actually cleared them was the other end of the same sentence --
    `iter_woven_segments` no longer erases the element, so the operand
    arrives typed and the backend gap is never reached. All six are gone
    and the waiver tuple with them.
  - `UniPass.get_all_sub_nodes` / `.find_parent_of_type` are `type[T]`
    TypeVar-generic statics that only forward to the same-named `UniNode`
    methods; the backend cannot lower a TypeVar-bound signature. They
    clear when generic statics lower, or when the forwarding shims are
    retired in favor of the `UniNode` methods they wrap.

`test_sealed_seam_reachability.jac` proves the other half for every
waiver: no waived name is reachable through native-internal calls from
the root's live entry surface, so each stub ships dead. Reachable
Python callers are routed by the layout registration, which never binds
a demoted method.

`sem_def_match_pass.jac` was measured for this wave (zero own seams, IR,
the same four-module closure) and refused: its live `connect_sems`
dispatches `Token.lit_value` through the vtable, and the
`String`/`MultiString` decoders are eval-bound Python-only stubs, so a
sealed build would abort on the first real semdef. The refusal and its
self-clearing condition are pinned in `test_sealed_seam_reachability.jac`.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     WAVE1_ROOTS: tuple = (
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac"
     );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE1_CLOSURES: dict[(str, tuple)] = {
         "jac0core/passes/annex_pass.jac": (
             "compiler/type_registry.jac",
             "compiler/type_system/type_utils.jac",
             "compiler/type_system/types.jac",
             "jac0core/codeinfo.jac",
             "jac0core/constant.jac",
             "jac0core/diagnostic_utils.jac",
             "jac0core/diagnostics.jac",
             "jac0core/helpers.jac",
             "jac0core/passes/annex_pass.jac",
             "jac0core/passes/annex_weave.jac",
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
         ),
         "jac0core/passes/module_codegen_pass.jac": (
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
         ),
         "jac0core/passes/uni_pass.jac": (
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
         ),
         "jac0core/passes/endpoint_effect_pass.jac": (
             "compiler/type_registry.jac",
             "compiler/type_system/type_utils.jac",
             "compiler/type_system/types.jac",
             "jac0core/codeinfo.jac",
             "jac0core/constant.jac",
             "jac0core/diagnostic_utils.jac",
             "jac0core/diagnostics.jac",
             "jac0core/helpers.jac",
             "jac0core/passes/endpoint_effect_pass.jac",
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


test "every wave-1 root is registered for the seal" {
    for rel in WAVE1_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate "
            "nothing at seal time"
        );
        for member in WAVE1_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each root's native closure is exactly the measured set" {
    for rel in WAVE1_ROOTS {
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
        assert seen == WAVE1_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE1_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each root's closure produces native IR" {
    for rel in WAVE1_ROOTS {
        (_coverage, has_ir, _errors) = _root_coverage(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam coverage would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-1 closure" {
    for rel in WAVE1_ROOTS {
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


test "every wave-1 seam waiver still matches a real seam" {
    for rel in WAVE1_ROOTS {
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
