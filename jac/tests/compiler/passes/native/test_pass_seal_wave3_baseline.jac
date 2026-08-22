"""Sealing wave 3: the reference-count fact solver joins the native seal.

Same discipline as `test_pass_seal_wave4_baseline.jac` and
`test_pass_seal_wave5_baseline.jac`: the root is measured exactly the way
`seal_native_artifacts` measures it, and three things are pinned --
exact closure membership, native IR production, and the seam set two-way
against `NATIVE_SEAL_DEMOTION_WAIVERS`.

The wave-3 coverage (#8271) refused all five analysis-cluster roots.
`rc_facts_pass` was refused at fourteen own seams whose named mechanism
was "`id()`-keyed identity stamps ... the `id()` builtin still does not
lower in these shapes, plus `rc_last_use`/`rc_move_in` field stamps and
dict/list literal shapes". Every clause of that refusal is now
discharged, and the shapes behind them were four distinct backend gaps,
not one:

  - `id()` refused a value wearing the `{i8 tag, T*}` optional jacket,
    which is what every `NameAtom.sym` read is. The emitter unwraps a
    pointer payload now, so the four identity stamps key natively.
  - `dataflow.jac`, the module `_solve_liveness` delegates to, typed its
    lattice element as a bare `set`. An erased element has no native
    storage, so both solvers demoted and cascaded back into this pass.
    The element is `set[SymId]` now and the module has no seams of its
    own -- and a set became iterable natively so that typing it was a
    gain rather than a trade.
  - `rc_last_use`, `rc_move_in` and the three `anon_region_*` stamps are
    `CodeGenTarget` fields, and `codeinfo.jac` is not in any pass's
    native closure. They are `Module` slots now, which is the same
    stamped-fact discipline wave 5 used in the other direction, and the
    native emitter reads the slot.
  - `is_builtin_region_name` was a pure unitree predicate marooned in
    `symbol_utils.jac`, whose own imports reach `jac0core/compiler.jac`.
    Calling it would have traded one seam for that whole module, so it
    is hoisted to the leaf `expr_keys.jac` -- and typed, since an
    `object` parameter is erased and does not lower either.

`dataflow.jac` stays a closure member rather than a root of its own:
with a handful of functions it would be an artifact of pure plumbing.

The other analysis-cluster roots are still refused, and
`REFUSED_OWN_SEAMS` below pins how far each one got so the refusal
cannot rot into a larger one unnoticed. Their blockers, named:

`static_analysis_pass` -- 8 own seams down to 6, and to **5** once the
pass base chain joined every root's closure and the pass's own
`transform` stopped routing through the Python-base bridge. The two that
cleared earlier were an undeclared `self._checked_scopes` stashed by
`transform` and read back as an inherited field, the same defect class
wave 5 cleared on `jsx_intrinsic_guard_pass`; it is a declared `has`
field now. The five that remain need three mechanisms this wave does not
build:

  - `expr_primitive_name` (reached by `_check_semantic_patterns`) takes
    `prog: object`, imports `JacProgram` at function scope and calls
    `prog.get_type_evaluator()` when a node carries no stamped type. It
    is honestly waived today. It clears when the type evaluator reaches
    passes as stamped data -- and note the fallback is the only coupled
    half, so a stamped-`.type`-only variant would clear the call site
    without clearing the function.
  - `report_placement_warnings` and `report_serverless_kind_errors`
    (`_check_placement_warnings`), plus `report_dead_client_import`
    (`_check_client_imports`), live in `symbol_utils.jac`, whose own
    imports reach `jac0core/compiler.jac`. Calling them natively would
    pull that module into the closure. They clear by the hoist this wave
    used for `is_builtin_region_name`, at roughly two hundred lines
    rather than ten.
  - `self.prog.type_evaluator.ambient_typing_names_by_module`
    (`_check_redundant_imports`) is a live driver read through the
    `prog: any` wall. It clears as a driver-stamped `Module` fact, the
    #8274/#8281 pattern.

  Two more are local shapes behind those: `_check_unreachable_code`
  reads `.body` off a bare `list` filled by `get_all_sub_nodes(typ=typ)`
  with a runtime type object, and `_check_client_imports` calls
  `startswith` on a value out of an untyped tuple list. Both are
  element erasure, and both sit in methods whose other blocker is one of
  the three above, so neither is worth churning alone. The pass also
  carries four type-checker errors of the same erasure -- a coverage report with
  errors reports "not reached", not "clean", so they gate a seal too.

`ownership_check_pass` -- refused, and the map is what this wave
produces for it rather than a fix. #8271 measured 60 own seams; the wave-3
coverage measured 26, and it measures **13** now. The last halving was not
work done on this pass: the `emit` family below was re-diagnosed as the
Python-base wall rather than a lowering gap -- `Transform` sat outside
this root's closure, so `self.emit` routed through the bridge, which
marshals only scalars and registered-struct pointers -- and the base
chain entering every root's closure made those calls resolve natively.
The recorded number is lowered here rather than the family's note being
rewritten, because the remaining 13 are the ones that were never about
`emit`.

The pass keys every `SymId` on `id(nd.sym)` and joins `set[SymId]`
lattices. Its entry point is a single `transform` (no `enter_node`), and
its 132 methods sit in five annexes of which four -- core, region,
sendability and markers -- touch no Python module and no driver state at
all. The families the 26 grouped into were six, and two were more than
half:

  - `emit` (11 seams) -- `_emit_diagnostics`, `_emit_borrow_diagnostics`,
    `_emit_loop_move_diagnostics`, `_emit_move_while_borrowed`,
    `_emit_escape_diagnostics`, `_emit_element_space_conflicts`,
    `_emit_region_escape`, `_emit_region_escape_diagnostics`,
    `_emit_post_seal_diagnostics`, `_emit_chunk_view_diagnostics` and
    `_emit_imm_mutation` all refuse as "inherited method call ...emit".
    Every one of them passes `related=`, and no emit in a root that
    already seals ever does.

    That correlation was read here as its cause, and it is not.
    `Transform.emit` does declare the parameter
    `(list[tuple[str, UniNode]] | None)`, but the backend does not refuse
    that type by name: a `(str, node)` pair is not mixed storage, the
    tuple branch gives each element its own slot, and the whole shape
    lowers wherever `UniNode` has a struct -- `Transform.emit`'s own body
    reaches zero seams when `transform.jac` is compiled as a root. The
    message that reading quoted appears only when the archetype is
    outside the compiling closure, which is a different fault.

    The real wall is the Python base. `Transform` is not in this root's
    native closure, so `self.emit(...)` routes through the Python-object
    bridge, and that bridge marshals int, bool, float, str and pointers
    to registered structs -- an aggregate is none of them, so the call
    refuses on the argument rather than on the type. The twelfth seam in
    `static_analysis_pass` is the same wall reached by a different type:
    `_check_undefined_names` passes an optional `str`, which the bridge
    cannot carry either.

    So the cheapest thing the next wave can buy here is not a lowering
    change at all -- it is putting `transform.jac` in the closure, which
    turns all twelve into ordinary native calls. Its own 33 seams are the
    price, and they are the measurement to take first.

    `_emit_view_diagnostics` is genuinely a mixed-storage refusal, and it
    is unrelated to `related=`: it walks `(kv.key, kv.value)`, and
    `KVPair` declares `key` optional and `value` not, so one slot would
    have to hold both an optional-pointer jacket and a bare pointer.
  - driver facts (5 seams) -- `_nogc_module_enforced`, `_nogc_check_call`
    and `_emit_enforcement_diagnostics` read `self.prog._compile_options`
    through the `prog: any` wall, fetching `nogc_enforce_all`,
    `nogc_cli_target`, `nogc_enforce_modules`, `nogc_grandfathered`,
    `na_gc_mode` and `nogc_debug` by `getattr` string key;
    `_nogc_resolve_provenance` additionally imports `os`, `fnmatch`,
    `jaclang` itself (for `__file__`) and calls `get_config()` inside
    bare excepts; `_nogc_setup` then stores the answer to a
    `CodeGenTarget` field. Every one is a driver fact, so the family
    clears the way wave 5 cleared its two roots and the way
    `rc_facts_pass` clears here: the driver resolves the provenance
    verdict once at the `run_schedule` seam and stamps a `Module` slot,
    and the pass consumes it. This is the family to land first -- it is
    the only one with a Python surface, and it is entirely inside
    `ownership_check_pass.enforce.impl.jac`.
  - bound-method transfers (3 seams) -- `_run_dataflow`,
    `_run_borrow_liveness` and `_run_reaching_borrows` hand
    `self._transfer`, `self._live_transfer` and `self._reaching_transfer`
    across the module boundary into `dataflow.jac` and refuse as
    inherited field reads. This is the exact shape `rc_facts_pass`
    cleared here, and `solve_backward_gen_kill` already exists for the
    liveness one; the other two need their gen/kill forms added
    alongside it.
  - cross-pass import (2 seams) -- `_nogc_infer_locals` and
    `_nogc_local_shape_expr_heap` call `result_ownership`, imported at
    function scope from `rc_facts_pass`. Worth re-measuring first now
    that that root seals.
  - local erasure (4 seams) -- `transform`'s inline field reset,
    `_emit_sendability_diagnostics` on a bare `set()`, `_flow_lend_joined`
    on an `AtomTrailer`, `_spawn_move_gen` on a `CompareExpr`. Small,
    and the same class this wave cleared in `rc_facts_pass`.
  - dead weight -- `_borrow_region` has no caller repo-wide and should
    leave before the pass is measured again; `_chunks_shape_of` returning
    a bare `(tuple | None)` is the pass's only element-erased signature.

`cfg_build_pass` was the fifth #8271 refusal and is no longer refused:
wave 6 sealed it as the fifteenth root, and it and this root reached
`compiler/expr_keys.jac` as a closure member independently -- cfg for
`collect_narrowing_symbols` / `collect_assigned_symbols`, this one for
the region predicate hoisted out of `symbol_utils.jac`. That leaves
`static_analysis_pass` and `ownership_check_pass` as the cluster's
remaining refusals, which is what `REFUSED_OWN_SEAMS` tracks.

B4 (#8323) then bought exactly what the `emit` family's analysis above
priced: `PLACEMENT_INFERENCE_HELD` emptied, `transform.jac` and
`uni_pass.jac` joined this cluster's closures, and ownership's census
dropped 26 -> 12 with the `emit` family reading empty -- all eleven, plus
`_run_borrow_liveness` and `_run_reaching_borrows`, whose bound-method
transfers stopped refusing as Python-base reads. `static_analysis_pass`
reads 6 -> 5 the same way (`_check_undefined_names`, the optional-`str`
twin of the emit wall, cleared). The price was not transform's own 33
seams as first quoted: rung 2 had already cut those to 3 by the time the
entry emptied, and the three ship waived in every sealed closure.

The measurement is a source-lane one: under a sealed jaclang image the
coverage reads the image's trust boundary instead of each unit's own
coupling, so `_root_coverage` skips there (both gates below).
"""

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
     WAVE3_ROOTS: tuple = ("compiler/passes/main/rc_facts_pass.jac", );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE3_CLOSURES: dict[(str, tuple)] = {
         "compiler/passes/main/rc_facts_pass.jac": (
             "compiler/expr_keys.jac",
             "compiler/passes/main/dataflow.jac",
             "compiler/passes/main/rc_facts_pass.jac",
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

"""Analysis-cluster roots still refused, and their own-seam count.

Refusing withholds the artifact, not the accounting: a refused root that
grows new seams is a regression, and one that loses them is progress the
next wave should collect. Neither may pass unnoticed.
"""
glob REFUSED_OWN_SEAMS: dict[(str, int)] = {
         "compiler/passes/main/static_analysis_pass.jac": 5,
         "compiler/passes/main/ownership_check_pass.jac": 12
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


test "every wave-3 root is registered for the seal" {
    for rel in WAVE3_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate "
            "nothing at seal time"
        );
        for member in WAVE3_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-3 root's native closure is exactly the measured set" {
    for rel in WAVE3_ROOTS {
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
        assert seen == WAVE3_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE3_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-3 root's closure produces native IR" {
    for rel in WAVE3_ROOTS {
        (_coverage, has_ir, _errors) = _root_coverage(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam coverage would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-3 closure" {
    for rel in WAVE3_ROOTS {
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


test "every wave-3 seam waiver still matches a real seam" {
    for rel in WAVE3_ROOTS {
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


test "each refused analysis root still measures its recorded seam count" {
    for (rel, expected) in sorted(REFUSED_OWN_SEAMS.items()) {
        assert rel not in NATIVE_SEAL_ROOTS , (
            f"{rel} is sealed now -- move it out of REFUSED_OWN_SEAMS and "
            "give it a closure and a waiver set above"
        );
        seams = _seams_by_key(rel);
        mine = sorted(
            k
            for k in seams
            if k.startswith(rel + "::")
        );
        assert len(mine) == expected , (
            f"{rel}: {len(mine)} own seams, recorded {expected}. If this "
            "dropped, collect the progress and lower the number; if it "
            "rose, the new seams are:\n"
            + "\n".join(f"  {k}: {seams[k]}" for k in mine)
        );
    }
}


test "the rc-facts solver keeps its stamps off the codegen target" {
    # `codeinfo.jac` is in no pass's native closure, so a `Module.gen`
    # field store is a store into a module this artifact cannot host --
    # it demoted `_stamp_last_use`, `_stamp_move_in` and
    # `_stamp_anon_regions` for exactly that reason. The facts live in
    # `Module` slots now; a re-introduced `.gen.` stamp would demote the
    # stamping method again.
    src = (PKG_PATH / "compiler/passes/main/rc_facts_pass.jac").read_text(
        encoding='utf-8'
    );
    src += (PKG_PATH / "compiler/passes/main/impl/rc_facts_pass.impl.jac").read_text(
        encoding='utf-8'
    );
    for token in (
        "gen.rc_last_use",
        "gen.rc_move_in",
        "gen.anon_region_open",
        "gen.anon_region_close",
        "gen.anon_region_locals",
        "symbol_utils"
    ) {
        assert token not in src , (
            f"rc_facts_pass reaches '{token}' again; that is the coupling "
            "this wave removed, and it demotes the reading method out of the "
            "sealed artifact"
        );
    }
}
