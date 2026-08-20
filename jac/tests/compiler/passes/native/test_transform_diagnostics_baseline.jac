"""Diagnostics coverage: the Transform unit owns no emission seam.

`Transform.emit` used to append every alert to `prog.errors_had` through the
`JacProgram` Python handle, and `Transform._is_suppressed` re-read project
config on each emission. Both are reachable on every diagnostic any pass
raises, so as native seams they were unwaivable: a sealed pass would abort on
its first emit. The redesign makes emission pure data accumulation -- alerts
land on the pass-local `errors_had` / `warnings_had` lists, suppression is a
lookup against the pre-resolved `DiagnosticPolicy` data object, and the
Python driver (`run_pass`) delivers to the program ledger after the pass body
finishes.

This coverage compiles `transform.jac` natively, the same measurement
`test_pass_driver_seam_baseline.jac` takes for the pass units, and pins that
the emission path stays seam-free: none of its callables demote, and none of
the module's residual native errors touch them. Callables off the emission
path that reach real Python machinery (console rendering, the cancel-token
handle, `RuntimeError` construction in `ice`) remain legal per-callable
seams and are waived one at a time.

**The unit is now module-fatally clean**, which is #8288 M1 rung 2, and the
inventory is pinned empty rather than deleted so that a regression has
somewhere to fail. Two entries cleared, each by a mechanism rather than a
loosening:

  - `prog: JacProgram` -- a field typed by a class the native lane has no
    layout for, reported twice once the constructor lowered far enough to
    type its parameter as well as its slot. The handle is a driver-stamped
    fact now: `pass_rim` sets it on the instance at construction, so the
    unsealed passes read `self.prog` unchanged and the sealable unit
    declares nothing.
  - `_require_native_pass_tier` was on the waived seam list, for consulting
    the sealed-image registry and triggering the serving binder. It moved to
    the same rim, and `test_sealed_pass_tier.jac` pins that the refusal it
    raises is unchanged in every situation that used to raise it.

`Transform.__post_init__` was on that waived list too, for "postinit's
generic field load and its `super` dispatch". The generic field load went
with rung 1: the pass base chain stopped being generic, so a slot that
lowered to a bare erased pointer is a `UniNode` now, and the constructor
lowers. Each waiver is dropped rather than reworded, which is the point of
pinning them two ways.

Rung 2 did not deliver closure membership and said so. Rung 3 does, and it
was not the fused root that delivered it: `transform.jac` reached
`codeinfo.jac` for `CodeLocInfo`, a symbol `srcloc.jac` declares and
`codeinfo` re-exports, and `codeinfo.jac` fails the native placement
pre-scan on its own `import from typing { Any }`. Since the pre-scan is
all-or-nothing over the transitive dependency set, that one import kept the
whole base chain out of every root's walk. Asking the declaring module
instead links all three base modules, so `NATIVE_SEAL_CLOSURE` gains this
unit and `NATIVE_SEAL_DEMOTION_WAIVERS` gains the three seams below -- the
bookkeeping this file's earlier revision described as not yet owed.

The measurement is a source-lane one. Under a sealed jaclang image every
method of an imported jaclang-internal archetype is untrusted by design, so
the coverage would read the image's trust boundary rather than the emission
path's own coupling; `_coverage` skips there.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob TRANSFORM_JAC = str(
         Path(jaclang.__file__).parent / "jac0core" / "passes" / "transform.jac"
     );

"""The emission path: every callable a single `self.emit(...)` can reach.

A seam on any of these is reachable on every diagnostic of every pass, so it
can never be waived.
"""
glob EMISSION_PATH: tuple = (
         "Transform.emit",
         "Transform._is_suppressed",
         "DiagnosticPolicy.is_suppressed",
         "DiagnosticPolicy._inline_suppressed",
         "Alert.postinit"
     );

"""Waived per-callable seams: real Python machinery off the emission path.

Two entries this table used to carry cleared for the fused prefix:
`BaseTransform.is_canceled` reads the `cancel_requested` scalar now (the
event poll moved to the driver and the Python loader), and `Transform.ice`
became the message-builder its callers raise
(`raise RuntimeError(self.ice(...))`), which the native raise path lowers.
"""
glob TRANSFORM_SEAM_WAIVERS: dict[(str, str)] = {
         "Alert.pretty_print": (
             "console rendering: calls `pretty_print_source_location` and "
             "`format_related_spans` from `helpers`; presentation stays "
             "Python-side."
         )
     };

"""Module-fatal backend gaps: none. Kept as an empty inventory rather than
deleted, so a construct that goes module-fatal again has a named place to
fail. Entries would be keyed by the construct the diagnostic names."""
glob KNOWN_CONSTRUCTOR_GAPS: tuple = ();

glob _COVERAGE_MEMO: list = [];

def _coverage -> tuple {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image, so na_ir_gen_pass "
            "untrusts every method of an imported jaclang-internal archetype "
            "that the image's layout does not carry; a source coverage here "
            "measures that trust boundary instead of the emission path's own "
            "coupling, which is what this file pins"
        );
    }
    if native_artifact_for("jaclang.jac0core.passes.transform") is not None {
        testskip(
            "transform.jac is served from this runtime's native seal; the "
            "coverage gated the build via seal_demotion_report"
        );
    }
    if _COVERAGE_MEMO {
        return _COVERAGE_MEMO[0];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=TRANSFORM_JAC,
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
    result = (coverage, ir, prog, );
    _COVERAGE_MEMO.append(result);
    return result;
}

"""Seams the coverage recorded inside transform.jac itself, keyed by callable."""
def _own_seams -> dict[(str, str)] {
    (coverage, _ir, _prog) = _coverage();
    rec = coverage.get(os.path.realpath(TRANSFORM_JAC));
    assert rec is not None , (
        "transform.jac never entered the native coverage -- the measurement "
        "is vacuous"
    );
    assert rec["outcome"] == "native" , (
        f"transform.jac did not stay native ({rec['outcome']}: "
        f"{rec['detail']}); per-seam data below would be incomplete"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    return found;
}

"""The unit's own native errors, as message strings."""
def _own_errors -> list[str] {
    (_coverage_map, _ir, prog) = _coverage();
    return [
        str(e)
        for e in prog.errors_had
        if "transform" in os.path.normpath(e.loc.mod_path)
    ];
}


test "the emission path owns no seam" {
    seams = _own_seams();
    offenders = sorted(
        f"{name}: {why}"
        for (name, why) in seams.items()
        if name in EMISSION_PATH
    );
    assert not offenders , (
        f"{len(offenders)} seam(s) on the always-reachable emission path -- "
        "emit must stay pure data accumulation, with delivery and config "
        "reads owned by the Python driver:\n"
        + "\n".join(f"  {s}" for s in offenders)
    );
}


test "no native error touches the emission path" {
    touched = [
        e
        for e in _own_errors()
        if any(
            marker in e
            for marker in (
                "'emit'",
                "'_is_suppressed'",
                "'is_suppressed'",
                "'_inline_suppressed'",
                "'prog.errors_had'",
                "'errors_had'"
            )
        )
    ];
    assert not touched , (
        "native errors name the emission path -- it regressed from pure "
        "data accumulation:\n"
        + "\n".join(f"  {e}" for e in touched)
    );
}


test "remaining seams are exactly the waived off-path callables" {
    seams = _own_seams();
    unexpected = sorted(
        k
        for k in seams
        if k not in TRANSFORM_SEAM_WAIVERS
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in the transform unit:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in TRANSFORM_SEAM_WAIVERS
        if k not in seams
    );
    assert not stale , (
        "waived transform seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {TRANSFORM_SEAM_WAIVERS[k]}" for k in stale)
    );
}


test "residual native errors are exactly the known constructor gaps" {
    errs = _own_errors();
    unexpected = [
        e
        for e in errs
        if not any(marker in e for marker in KNOWN_CONSTRUCTOR_GAPS)
    ];
    assert not unexpected , (
        f"{len(unexpected)} native error(s) beyond the known constructor " "gaps:\n"
        + "\n".join(f"  {e}" for e in unexpected)
    );
    # Deduplicated, because the count that matters is how many distinct
    # gaps are left, not how many times the emitter reaches one of them.
    # The inventory is empty as of rung 2: `prog: JacProgram` was the last
    # entry and was reported twice, one gap at two sites, and it cleared in
    # one move when the handle left the base for the rim.
    distinct = sorted(set(errs));
    assert len(distinct) == len(KNOWN_CONSTRUCTOR_GAPS) , (
        f"constructor-gap inventory drifted (expected "
        f"{len(KNOWN_CONSTRUCTOR_GAPS)} distinct, got {len(distinct)}) -- "
        "update KNOWN_CONSTRUCTOR_GAPS so the sealing lane sees what is "
        "left:\n"
        + "\n".join(f"  {e}" for e in distinct)
    );
}


test "the unit is clean enough to link, and the sealed roots link it" {
    (coverage, _ir, _prog) = _coverage();
    linked = sorted(
        os.path.relpath(p, os.path.dirname(os.path.realpath(jaclang.__file__)))
        for p in coverage
        if os.path.realpath(p) != os.path.realpath(TRANSFORM_JAC)
    );
    # `transform.jac` compiles as a root here with no module-fatal error and
    # its own closure is the ordinary unitree family every root carries, so
    # nothing about the unit blocks a root from linking it. That direction
    # was always true. The other direction -- whether any root's walk
    # *reaches* transform.jac -- turned on a single re-export import and is
    # true now, which is why `NATIVE_SEAL_CLOSURE` lists this unit and the
    # three seams above are waived rather than merely inventoried.
    assert linked , (
        "transform.jac's own closure is empty, so the compile was never "
        "reached and the seam coverage above is vacuous"
    );
    assert "jac0core/unitree.jac" in linked , (
        f"transform.jac stopped linking unitree ({linked}); the measurement "
        "moved rather than the unit getting cleaner"
    );
    assert "jac0core/codeinfo.jac" not in linked , (
        "transform.jac reaches codeinfo.jac again. codeinfo fails the native "
        "placement pre-scan, and the pre-scan is all-or-nothing over the "
        "transitive set, so this does not cost compile time -- it takes the "
        "whole base chain back out of every sealed root's walk"
    );
    import from jaclang.utils.precompile_bytecode {
        NATIVE_SEAL_CLOSURE,
        NATIVE_SEAL_DEMOTION_WAIVERS
    }
    assert "jac0core/passes/transform.jac" in NATIVE_SEAL_CLOSURE , (
        "the roots link transform.jac but NATIVE_SEAL_CLOSURE does not "
        "account for it"
    );
    # Checked against an ordinary consumer root rather than one of the
    # chain's own members: `uni_pass.jac` and `module_codegen_pass.jac`
    # resolve some of these on their own and carry reduced, measured sets,
    # so they are the wrong place to ask whether the seam is accounted for.
    ordinary = NATIVE_SEAL_DEMOTION_WAIVERS["jac0core/passes/ast_validation_pass.jac"];
    for seam in TRANSFORM_SEAM_WAIVERS {
        assert f"jac0core/passes/transform.jac::{seam}" in ordinary , (
            f"{seam} is demoted inside a unit the roots now link, and no "
            "waiver names it"
        );
    }
}
