"""Sealing wave 5: the two driver-fact readers join the native seal.

Same discipline as `test_pass_seal_wave4_baseline.jac`: each root is
measured exactly the way `seal_native_artifacts` measures it, and three
things are pinned per root -- exact closure membership, native IR
production, and the seam set two-way against
`NATIVE_SEAL_DEMOTION_WAIVERS`.

Both wave-5 roots read facts that only the driver can answer, and both
cleared the same way #8274 cleared `sym_tab_build_pass`: the driver
computes the fact at the `run_schedule` seam and stamps it on the
module, and the pass consumes the slot.

  - `jsx_intrinsic_guard_pass` reached `self.prog._compile_options` (the
    `Transform.prog` wall) and called the config-backed client-kind
    resolver in `before_pass`, and wrote two undeclared `self._x` attrs
    that every other method then read back as inherited fields. The
    verdict is `Module.mobui_enforced_root` now, stamped immediately
    before the pass runs, and the two working fields are declared. Its
    closure lost `project/client_kind.jac` outright and kept only the
    two pure path/tag tables it actually reads.
  - `access_check_pass` called `get_config` for its enforce flag and
    `find_jac_project_root` twice per cross-module name, and forwarded
    `**kwargs` into the inherited `emit`. The two facts are
    `Module.access_enforced` and `Module.jac_project_root`, stamped for
    every module that runs any schedule, and the emit-pair helper is
    four explicit-keyword emits.

Neither root needs a waiver of its own: the ten entries each one carries
are the shipped `unitree` family, unchanged by this wave.

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
     WAVE5_ROOTS: tuple = (
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/main/access_check_pass.jac"
     );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE5_CLOSURES: dict[(str, tuple)] = {
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac": (
             "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
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
             "project/client_kind_paths.jac",
             "runtimelib/client/targets/react_native/html_tag_map.jac",
             "runtimelib/na_stdlib/_hashlib_native.jac",
             "runtimelib/na_stdlib/contextvars.jac",
             "runtimelib/na_stdlib/fnmatch.jac",
             "runtimelib/na_stdlib/hashlib.jac",
             "runtimelib/na_stdlib/logging.jac",
             "runtimelib/na_stdlib/pathlib.jac"
         ),
         "compiler/passes/main/access_check_pass.jac": (
             "compiler/passes/main/access_check_pass.jac",
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


test "every wave-5 root is registered for the seal" {
    for rel in WAVE5_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate "
            "nothing at seal time"
        );
        for member in WAVE5_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-5 root's native closure is exactly the measured set" {
    for rel in WAVE5_ROOTS {
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
        assert seen == WAVE5_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE5_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-5 root's closure produces native IR" {
    for rel in WAVE5_ROOTS {
        (_coverage, has_ir, _errors) = _root_coverage(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam coverage would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-5 closure" {
    for rel in WAVE5_ROOTS {
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


test "every wave-5 seam waiver still matches a real seam" {
    for rel in WAVE5_ROOTS {
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


test "neither wave-5 root reaches its driver's facts on its own" {
    # The seal is only honest if the passes read the stamped slots
    # instead of recomputing them: a re-introduced `get_config`,
    # `find_jac_project_root` or `resolve_client_kind_context` call
    # would demote the reading method again, and a `**kwargs` forward
    # into `emit` would demote every emit site.
    for (rel, banned) in (
        (
            "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
            ("resolve_client_kind_context", "self.prog")
        ),
        (
            "compiler/passes/main/access_check_pass.jac",
            ("get_config", "find_jac_project_root", "**kwargs")
        )
    ) {
        src = (PKG_PATH / rel).read_text(encoding='utf-8');
        annex = PKG_PATH
            / rel.replace("/main/", "/main/impl/").replace(".jac", ".impl.jac");
        if annex.exists() {
            src += annex.read_text(encoding='utf-8');
        }
        for token in banned {
            assert token not in src , (
                f"{rel} reads '{token}' again; that is the driver coupling "
                "this wave removed, and it demotes the reading method out "
                "of the sealed artifact"
            );
        }
    }
}
