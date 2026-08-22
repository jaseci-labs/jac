"""Sealing wave 7: the CFG builder joins the native seal.

Same discipline as `test_pass_seal_wave5_baseline.jac`: the root is measured
exactly the way `seal_native_artifacts` measures it, and three things are
pinned -- exact closure membership, native IR production, and the seam set
two-way against `NATIVE_SEAL_DEMOTION_WAIVERS`.

`cfg_build_pass` reaches the seal on a hoist that already landed:
`collect_narrowing_symbols` and `collect_assigned_symbols` now come from
`compiler/expr_keys.jac`, which imports only `unitree` and `constant`, so the
narrowing key work no longer drags `symbol_utils` (and the type evaluator
behind it) into the unit. That is the whole reason this closure is thirteen
modules and not the analysis cluster's.

Four seams stay, and every one of them is named in
`_CFG_BUILD_SEAM_WAIVERS`:

  - `cfg_dot_from_file` opens a file and drives a whole `JacProgram`. It is
    the `jac dot` tool, not the compile schedule.
  - `CoalesceBBPass.enter_node` and `._node_label` are that tool's pass.
    `enter_node` subscripts `basic_blocks`, a
    `dict[int, dict[str, list[UniCFGNode]]]` whose inner entry reaches the
    emitter as a bare pointer with no layout attached -- the shape #8288 M2
    stopped compiling to a character read. `_node_label` cascades on
    `unparse_node`.
  - `CFGBuildPass._find_next_cfg_stmt_after` is the one seam on the real
    schedule: it reads a `Sequence` element through `cast`.

The measurement is a source-lane one: under a sealed jaclang image the coverage
reads the image's trust boundary instead of the unit's own coupling, so
`_root_coverage` skips there.
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
     WAVE6_ROOTS: tuple = ("compiler/passes/main/cfg_build_pass.jac", );

"""The root's exact native closure, as package-relative paths."""
glob WAVE6_CLOSURES: dict[(str, tuple)] = {
         "compiler/passes/main/cfg_build_pass.jac": (
             "compiler/expr_keys.jac",
             "compiler/passes/main/cfg_build_pass.jac",
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


test "every wave-6 root is registered for the seal" {
    for rel in WAVE6_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate "
            "nothing at seal time"
        );
        for member in WAVE6_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-6 root's native closure is exactly the measured set" {
    for rel in WAVE6_ROOTS {
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
        assert seen == WAVE6_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE6_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-6 root's closure produces native IR" {
    for rel in WAVE6_ROOTS {
        (_coverage, has_ir, _errors) = _root_coverage(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam coverage would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-6 closure" {
    for rel in WAVE6_ROOTS {
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


test "every wave-6 seam waiver still matches a real seam" {
    for rel in WAVE6_ROOTS {
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


test "the cfg narrowing keys come from the native-clean hoist" {
    src = (PKG_PATH / "compiler/passes/main/impl/cfg_build_pass.impl.jac").read_text();
    assert "jaclang.compiler.expr_keys" in src , (
        "cfg_build must read its narrowing/assigned key helpers from "
        "compiler/expr_keys.jac; that hoist is what keeps symbol_utils and "
        "the type evaluator out of this closure"
    );
    assert "symbol_utils" not in src , (
        "a symbol_utils import in cfg_build re-couples the pass to the "
        "analysis cluster and this closure stops being sealable"
    );
}
