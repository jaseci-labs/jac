"""The JCIR emitter joins the native seal, measured the way the sealer measures.

Same discipline as `test_pass_seal_wave1_census.jac` and its wave-2
sibling: the root is compiled exactly as `seal_native_artifacts` compiles
it, and three things are pinned -- exact closure membership, native IR
production, and the seam set two-way against
`NATIVE_SEAL_DEMOTION_WAIVERS`.

What cleared this root, from 86 own seams to 24:

  - The recipe sink held `CgNode` and `CgSplice`, so it could not be
    typed past bare `list`. A shared `CgItem` base made
    `dict[UniNode, list[CgItem]]` possible, and typing it lowered
    `outs`/`set_out`/`val` and the emitter's whole plumbing.
  - `dict.get` does not lower over a typed value; membership plus index
    does. That rewrite alone cleared 79 cascades across the emitter and
    the container writer.
  - `BaseAstGenPass[T]`'s type parameter collided with `uni_pass`'s
    `glob T`, so `_flatten_ast_list` bound its element type to a unitree
    node. Renaming the parameter fixed the binding; a monomorphic
    override on this pass cleared `resolve_stmt_block` and its sixteen
    statement-visitor cascades.
  - 35 accumulators, the operator tables (keyed on token names rather
    than built into enum members at emit time), the never-taken `ice`
    guards, and the element-erased `sorted`/`.values()` reads.
  - `codegen_ir.jac` reached zero own seams once its reader moved to the
    shim, where the internals doc already placed it.

The residue is four families, each waived with the mechanism that
clears it:

  - `_JCIR_INTEROP_SEAM_WAIVERS`: the native-export and sv-to-sv stub
    surface reads `gen.interop_manifest` and the `InteropBinding` /
    `BoundaryTypeInfo` codeinfo objects, which are Python codegen state.
    The driver half of this family is retired: `exit_import` consumed
    `self.prog` -- the only such read in any sealed pass -- and now
    consumes `Import.native_only_drop`, stamped by
    `JacCompiler.stamp_native_import_facts` in the #8242 `absorbed_mod`
    pattern. What is left clears when the manifest crosses as a
    native-clean record instead of a Python object.
  - `_JCIR_LOWERING_SEAM_WAIVERS`: named backend gaps -- an `Ellipsis`
    constant, element-erased list reads, `_merge_module_bodies` on the
    generic base. Each clears when the named construct lowers.
  - `_JCIR_ENTITY_SEAM_WAIVERS`: jsx text and string attributes decode
    html entities. Clears with an na_stdlib `html` shim carrying the
    html5 entity table, pinned against `html.unescape` the way
    `test_jcir_facts_sync.jac` pins the other baked facts. A reduced
    table is not acceptable here: the two lanes must agree byte for
    byte, so a missing entity is a silent divergence.
  - `_JCIR_EMITTER_ICE_SEAM_WAIVERS`: `_query_filter_kws` refuses with
    an emitter-internal error rather than a named gap, and takes its two
    callers with it. Restructuring away union locals, `any` locals,
    conditional expressions and continue-guards does not move it, which
    places the fault in the native emitter. Its sibling
    `exit_delete_stmt` was in the same state and cleared when its nested
    function became a method, so nested-function lowering is the first
    place to look. Clears when that emitter fault is fixed, not by
    reshaping this source.

The measurement is a source-lane one: under a sealed jaclang image the
census reads the image's trust boundary instead of the unit's own
coupling, so `_root_census` skips there (both gates below).
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_REFUSED_ROOTS,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     JCIR_ROOT: str = "jac0core/passes/jcir_gen_pass.jac";

"""The emitter's exact native closure, as package-relative paths.

The eight members the emitter reaches on its own are joined by the type
system's passenger set, which arrives through `unitree`: three `TypeBase`
-typed fields make `types.jac`, `type_utils.jac` and `type_registry.jac` a
layout dependency of every sealed artifact, `helpers.jac` follows them, and
the `na_stdlib` hash and path shims follow `helpers`. None of those is
called from the emitter's entry surface, which is what
`test_sealed_seam_reachability.jac` proves; they are linked, not reached.
"""
glob JCIR_CLOSURE: tuple = (
         "compiler/type_registry.jac",
         "compiler/type_system/type_utils.jac",
         "compiler/type_system/types.jac",
         "jac0core/codegen_ir.jac",
         "jac0core/constant.jac",
         "jac0core/diagnostics.jac",
         "jac0core/helpers.jac",
         "jac0core/jcir_facts.jac",
         "jac0core/passes/jcir_gen_pass.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/pathlib.jac",
         "runtimelib/na_stdlib/textwrap.jac"
     );

"""Closure members that must carry no seam of their own."""
glob JCIR_CLEAN_MEMBERS: tuple = (
         "jac0core/codegen_ir.jac",
         "jac0core/constant.jac",
         "jac0core/diagnostics.jac",
         "jac0core/jcir_facts.jac",
         "jac0core/srcloc.jac",
         "runtimelib/na_stdlib/textwrap.jac"
     );

glob _CENSUS_MEMO: dict[(str, tuple)] = {};

"""A root's dotted module name, for the sealed-runtime skip gate."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Compile the root the way seal_native_artifacts does, up to the census."""
def _root_census(rel: str) -> tuple {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image; a source census here "
            "measures the image's trust boundary, not the unit's own seams"
        );
    }
    if native_artifact_for(_root_module_name(rel)) is not None {
        testskip(
            f"{rel} is served from this runtime's native seal; the census "
            "gated the build via seal_demotion_report"
        );
    }
    if rel in _CENSUS_MEMO {
        return _CENSUS_MEMO[rel];
    }
    prog = JacProgram();
    na_census_begin();
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
        census = na_census_end();
    }
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    result = (census, has_ir, errors, );
    _CENSUS_MEMO[rel] = result;
    return result;
}

"""Census seams as `<pkg-rel module>::<Type>.<method>` -> reason."""
def _seams_by_key(rel: str) -> dict[(str, str)] {
    (census, _has_ir, _errors) = _root_census(rel);
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(census.items()) {
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


test "the jcir root is registered for the seal" {
    assert JCIR_ROOT in NATIVE_SEAL_ROOTS , (
        f"{JCIR_ROOT} is not in NATIVE_SEAL_ROOTS; this census would gate "
        "nothing at seal time"
    );
    assert JCIR_ROOT not in NATIVE_SEAL_REFUSED_ROOTS , (
        f"{JCIR_ROOT} is both sealed and recorded as refused; it has to be "
        "one or the other"
    );
    for member in JCIR_CLOSURE {
        assert member in NATIVE_SEAL_CLOSURE , (
            f"{JCIR_ROOT} pulls {member} into its native unit but "
            "NATIVE_SEAL_CLOSURE does not account for it"
        );
    }
}


test "the jcir root's native closure is exactly the measured set" {
    (census, _has_ir, errors) = _root_census(JCIR_ROOT);
    assert not errors , (
        f"{JCIR_ROOT} compile errors (closure below is 'not reached', not "
        f"'clean'): {errors[:5]}"
    );
    seen = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix() for p in census
        )
    );
    assert seen == JCIR_CLOSURE , (
        f"{JCIR_ROOT}: native closure changed: {seen} != {JCIR_CLOSURE}. "
        "A new member has to reach zero un-waived seams before this root "
        "can keep sealing."
    );
}


test "the jcir root's closure produces native IR" {
    (_census, has_ir, _errors) = _root_census(JCIR_ROOT);
    assert has_ir , (
        f"no LLVM IR for {JCIR_ROOT} -- the compile aborted before codegen, "
        "so a zero-seam census would mean 'not reached', not 'clean'"
    );
}


test "no un-waived seam in the jcir closure" {
    seams = _seams_by_key(JCIR_ROOT);
    (allowed, _bare) = seal_waiver_names(JCIR_ROOT);
    unexpected = sorted(
        k
        for k in seams
        if k not in allowed
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in {JCIR_ROOT}'s sealed " "closure:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
}


test "every jcir seam waiver still matches a real seam" {
    seams = _seams_by_key(JCIR_ROOT);
    (allowed, _bare) = seal_waiver_names(JCIR_ROOT);
    stale = sorted(
        k
        for k in allowed
        if k not in seams
    );
    assert not stale , (
        f"{JCIR_ROOT} waives seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}" for k in stale)
    );
}


test "the container format and the baked facts carry no seam" {
    seams = _seams_by_key(JCIR_ROOT);
    for member in JCIR_CLEAN_MEMBERS {
        dirty = sorted(
            k
            for k in seams
            if k.startswith(member + "::")
        );
        assert not dirty , (
            f"{member} is in the emitter's sealed closure and has to stay "
            f"free of seams of its own; it grew {len(dirty)}:\n"
            + "\n".join(f"  {k}: {seams[k]}" for k in dirty)
        );
    }
}


test "the closure's own module-level functions are not the root's to waive" {
    # The rule this once enforced -- that no waived name may be a
    # module-level function of a dependency -- was a static stand-in for
    # the load canary, and it does not survive the closure the emitter
    # actually links. `type_utils`, `types` and `helpers` join every
    # sealed artifact as a layout dependency of `unitree`, they carry
    # eleven, one and four demoted free functions respectively, and the
    # artifact still links and loads: the seal's own `dlopen` plus
    # symbol probe runs on every build and is green for this root.
    #
    # `codegen_ir`'s `decode_ops`, the failure this rule was written for,
    # is caught by the check above instead: the container format is a
    # JCIR_CLEAN_MEMBER and may carry no seam at all, so it can never
    # reach the advertised-and-absent state. What is left here is the
    # accounting -- a dependency's free function is the closure's debt,
    # recorded against the module that owns it, and the root may not
    # quietly adopt one that its own closure does not already carry.
    (allowed, _bare) = seal_waiver_names(JCIR_ROOT);
    foreign = sorted(
        q
        for q in allowed
        if "." not in q.partition("::")[2] and q.partition("::")[0] != JCIR_ROOT
    );
    for q in foreign {
        owner = q.partition("::")[0];
        assert owner in JCIR_CLOSURE , (
            f"{JCIR_ROOT} waives {q}, whose module is not in the emitter's "
            "measured closure. A waiver for a module the artifact does not "
            "link is accounting for work that is not happening here"
        );
    }
}
