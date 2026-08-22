"""Driver-orchestration coverage: pass units own no compile-driver seams.

`SymTabBuildPass` and `JacAnnexPass` are tree/symbol transformations. Resolving
import paths (importlib / sys.path / pathlib), walking the filesystem for annex
files, reading source files, re-entering the parser, and triggering dependency
compiles are compile-driver responsibilities (`JacCompiler` / `JacProgram`),
and a pass that reaches for them can never seal: unlike a backend gap, such a
seam is reachable on ANY input that contains an import or has an annex file, so
it is unwaivable -- a sealed pass would abort on the first real module.

This coverage compiles each pass unit natively, the same measurement
`test_unitree_seal_baseline.jac` takes for unitree, and pins the unit's own seam
inventory. The driver hands each pass its inputs as data instead of letting the
pass fetch them: the resolved module of an absorb import arrives on
`Import.absorbed_mod` (stamped by `JacCompiler.resolve_absorb_imports`), and
pre-parsed annex trees arrive on `Module.annex_mods` (stamped by
`JacCompiler.load_annex_modules`). Backend gaps -- constructs the native
backend cannot lower yet -- remain legal seams and are waived one at a time
below; a seam that names a driver entry point fails regardless of waivers.

The measurement is a source-lane one. Under a sealed jaclang image every
method of an imported jaclang-internal archetype is untrusted by design, so
the coverage would read the image's trust boundary rather than the pass unit's
own coupling; `_pass_coverage` skips there.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PASSES_DIR = Path(jaclang.__file__).parent / "jac0core" / "passes";

"""Substrings that mark a seam as driver coupling rather than a backend gap.

Construct names appear single-quoted in demotion diagnostics ("Native lowering
failed for function 'rd_parse'"), so the quoted markers cannot collide with the
file paths the diagnostics embed.
"""
glob DRIVER_SEAM_MARKERS: tuple = (
         "'prog'",
         "'resolve_relative_path'",
         "'compile'",
         "'load_dependency_module'",
         "'discover_annex_files'",
         "'discover_base_file'",
         "'rd_parse'",
         "'read_file_with_encoding'"
     );

"""Backend gaps that keep a sym_tab_build method demoted, keyed as the coverage
keys them. None of these touch the driver: each names a construct the native
backend cannot lower yet, and each stays reachable through its Python fallback.

Empty twice over. `SymTabBuildPass.exit_global_vars` left when the
inherited-slot repair (#8320) linked the base chain's method slots, and it
stays out with `transform.jac` in the unit since B4 emptied
`PLACEMENT_INFERENCE_HELD`: the call to the inherited `Transform.ice`
resolves against the in-unit demotion verdict and the method lowers. Kept
as an inventory so a new backend gap has a named place to land.
"""
glob SYM_TAB_SEAM_WAIVERS: dict[(str, str)] = {};

glob _COVERAGE_MEMO: dict[(str, tuple)] = {};

"""Compile one pass unit natively and return (coverage, module_ir)."""
def _pass_coverage(pass_file: str) -> tuple {
    unit = f"jaclang.jac0core.passes.{pass_file[:-4]}";
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image, so na_ir_gen_pass "
            "untrusts every method of an imported jaclang-internal archetype "
            "that the image's layout does not carry; a source coverage here "
            "measures that trust boundary (`UniScopeNode.def_insert`, "
            "`Module.add_kids_right`) instead of the pass unit's own driver "
            "coupling, which is what this file pins"
        );
    }
    if native_artifact_for(unit) is not None {
        testskip(
            f"{pass_file} is served from this runtime's native seal; the "
            "coverage gated the build via seal_demotion_report"
        );
    }
    if pass_file in _COVERAGE_MEMO {
        return _COVERAGE_MEMO[pass_file];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(PASSES_DIR / pass_file),
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
    result = (coverage, ir, );
    _COVERAGE_MEMO[pass_file] = result;
    return result;
}

"""The seams the coverage recorded inside the pass's own file, keyed by method."""
def _own_seams(pass_file: str) -> dict[(str, str)] {
    (coverage, _ir) = _pass_coverage(pass_file);
    rec = coverage.get(os.path.realpath(str(PASSES_DIR / pass_file)));
    assert rec is not None , (
        f"{pass_file} never entered the native coverage -- the measurement is "
        "vacuous"
    );
    assert rec["outcome"] == "native" , (
        f"{pass_file} did not stay native ({rec['outcome']}: {rec['detail']}); "
        "per-seam data below would be incomplete"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    return found;
}

"""Seams among `seams` whose reason names a compile-driver entry point."""
def _driver_seams(seams: dict[(str, str)]) -> list[str] {
    return sorted(
        f"{name}: {why}"
        for (name, why) in seams.items()
        if any(marker in why for marker in DRIVER_SEAM_MARKERS)
    );
}


test "sym_tab_build unit produces native IR" {
    (_coverage, ir) = _pass_coverage("sym_tab_build_pass.jac");
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "no LLVM IR for sym_tab_build_pass.jac -- the compile aborted before "
        "codegen, so an empty driver-seam list would mean 'not reached', not "
        "'clean'"
    );
}


test "sym_tab_build owns no import-orchestration seam" {
    offenders = _driver_seams(_own_seams("sym_tab_build_pass.jac"));
    assert not offenders , (
        f"{len(offenders)} driver-coupling seam(s) in the sym_tab_build unit "
        "-- import resolution and dependency compiles belong to the driver, "
        "which hands the pass its data on `Import.absorbed_mod`:\n"
        + "\n".join(f"  {s}" for s in offenders)
    );
}


test "sym_tab_build's remaining seams are exactly the waived backend gaps" {
    seams = _own_seams("sym_tab_build_pass.jac");
    unexpected = sorted(
        k
        for k in seams
        if k not in SYM_TAB_SEAM_WAIVERS
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in the sym_tab_build unit:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in SYM_TAB_SEAM_WAIVERS
        if k not in seams
    );
    assert not stale , (
        "waived sym_tab_build seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {SYM_TAB_SEAM_WAIVERS[k]}" for k in stale)
    );
}


test "annex_pass unit produces native IR" {
    (_coverage, ir) = _pass_coverage("annex_pass.jac");
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "no LLVM IR for annex_pass.jac -- the compile aborted before codegen, "
        "so an empty seam list would mean 'not reached', not 'clean'"
    );
}


test "annex_pass owns no seam at all and the merge lowers" {
    seams = _own_seams("annex_pass.jac");
    assert not seams , (
        f"{len(seams)} seam(s) in the annex_pass unit -- annex discovery and "
        "parsing belong to the driver, which hands the pass pre-parsed trees "
        "on `Module.annex_mods`, and the merge itself lowers:\n"
        + "\n".join(f"  {k}: {v}" for (k, v) in sorted(seams.items()))
    );
    (_coverage, ir) = _pass_coverage("annex_pass.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "annex_pass produced no native layout";
    for method in ("JacAnnexPass.transform", "JacAnnexPass._merge_annex") {
        assert method in layout.methods , (
            f"{method} fell out of the native layout -- the merge must stay "
            "a pure, lowerable tree transformation"
        );
    }
}


test "annex_pass no longer imports the annex-discovery driver" {
    import jaclang.jac0core.passes.annex_pass as annex_unit;
    assert not hasattr(annex_unit, "discover_annex_files") , (
        "annex_pass binds `discover_annex_files` at module scope -- the "
        "bccache filesystem walk is the driver's, not the pass unit's"
    );
}
