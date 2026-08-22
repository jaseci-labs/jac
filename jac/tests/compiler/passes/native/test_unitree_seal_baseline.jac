"""A0 gate: `unitree.jac` and its whole native closure lower with no seams.

`unitree` cannot join `NATIVE_SEAL_ROOTS` until every module the native
compile drags in with it lowers in full: a seam in a sealed artifact ships as
an `abort()` stub, so one un-lowered method kills the process on first call.
The seal's own refusal (`seal_demotion_report`) reads the same coverage this
test reads, so this is the seal verdict without the link and the dlopen.

Two things are asserted, and the closure assertion is the load-bearing one.
The measurement the epic quotes covers `unitree.jac` alone; the modules it
pulls in were never measured, so "unitree seals when its own seams reach zero"
was unproven. Pinning the closure membership makes any new native dependency
(a module-level import replacing a typing-only or function-local one) a loud
failure here rather than a surprise at seal time.

Waivers are enumerated one seam at a time and name what blocks each, so the
suite never degrades into a "fewer than N seams" threshold: an un-waived seam
fails, and a waiver that stops matching a real seam fails too. Two kinds are
waived, and only two: a backend gap, named by the construct it cannot lower,
and a method that calls Python-only infrastructure (import resolution, the
type system, CPython `ast` handles) which no native unit can host. Neither
kind is reachable from a parse, and that is proved rather than asserted:
`test_sealed_seam_reachability.jac` builds an over-approximated call closure
from the sealed entry points and fails if any name below is in it.

`eval` used to be the third kind, and it is gone: `String.lit_value` and
`MultiString.lit_value` decoded literals through CPython, which stranded
every sealed caller of a literal value -- `sem_def_match_pass.connect_sems`
among them -- on an abort stub. `unitree.decode_string_literal` replaced it
with one implementation both lanes run, proved CPython-exact against `eval`
in `tests/compiler/test_literal_decoding.jac`, so the pair lowers and the
two waivers are gone rather than reworded.

The closure went from three modules to eleven when `ClassVar` joined the
compile-time import vocabulary. `types.jac` declares its per-subclass
`CATEGORY` slots with it, and `scan_native_blockers` read that line-4
`import from typing { ClassVar }` as a non-native import, so the keystone
could never be linked and `unitree`'s three `TypeBase`-typed fields were a
layout dependency on a module the unit was not allowed to contain. With the
keystone linkable the unit grows by the type system's lower half plus the
pure-leaf modules those two drag in.

Thirty seams, and most of them are one of two causes rather than thirty
separate ones: an imported archetype's layout is not reachable for
`isinstance` even when its module is in the unit; and a function-local
`import jaclang.jac0core.unitree`
in `helpers.jac` -- the one thing keeping `helpers` out of a module-level
cycle -- is a Python module import the native lane refuses. The rest are
cascades on those, each naming its callee.

A third cause used to head that list and is gone. `create_callable_type`
reads `ParameterCategory.Positional`, an `IntEnum` member off the class, and
the members are spelled `auto()` -- a value no constant fold reached, so the
layout had no table to read. Generated enum values resolve beside the
layout now, so the read lowers and the waiver went with it.

Growing the closure was a net subtraction of four waivers.
`Ability.event_trigger_type_names` was waived for calling `TypeBase.mangle`
"through a typing-only import", and now that `types.jac` is in the unit it
lowers. `type_utils.lookup_symtab` was waived for calling the imported
generic `UniNode.find_parent_of_type`, which monomorphizes across the
boundary now that the failure path erases an unfillable specialization shell
instead of leaving it in the module. `convert_to_instance` and
`apply_solved_type_vars` were waived as cascades on
`ClassType.clone_as_instance`, and they lower now that the importer has a
verdict for it: a demoted method keeps its own name and stays in
`layout.functions` as an abort stub, and availability is read off that table,
so the call resolves. Two new seams arrived with
#8272's verdict-before-emission protocol -- `FunctionType.specialize` and
`collect_member_syms` -- both cross-module cascades that used to link against
a renamed symbol instead of demoting.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     UNITREE_SRC = PKG_PATH / "jac0core" / "unitree.jac";

"""Every module the native compile of `unitree.jac` puts in its closure.

`types.jac` and `type_utils.jac` are the type system's lower half, pulled in
by unitree's `TypeBase`-typed fields once the keystone became linkable.
`helpers.jac` arrives with them, and `pathlib`, `fnmatch`, `hashlib`,
`_hashlib_native` and `type_registry` are pure leaves those two reach.

The pass spine joined when B4 (#8323) emptied `PLACEMENT_INFERENCE_HELD`:
`codeinfo` arrives through unitree's own `import type` edge (the same edge
kind that pulled `types.jac` in) and through `UniNode.gen`'s function-local
import, which now lowers; `uni_pass` through the `import type { UniPass }`
the visitor signatures carry; and `module_codegen_pass`, `transform`,
`diagnostics`, `diagnostic_utils`, `contextvars` and `logging` ride their
module-level imports. Only `codeinfo` brings seams, all
waived below (`transform`'s trio cleared -- the gutter formatting, the
cancel scalar, `ice` as a message-builder -- and the base-chain field
wall is down everywhere: every measured root lowers
`__post_init__`/`transform`/`traverse` now); the old reading that `codeinfo` could "never share
a native unit with unitree" predicted a cycle that `import type` erasure
never actually forms. `treeprinter` stays absent: function-local only.
"""
glob UNITREE_CLOSURE: tuple = (
         "_hashlib_native.jac",
         "codeinfo.jac",
         "constant.jac",
         "contextvars.jac",
         "diagnostic_utils.jac",
         "diagnostics.jac",
         "fnmatch.jac",
         "hashlib.jac",
         "helpers.jac",
         "logging.jac",
         "module_codegen_pass.jac",
         "pathlib.jac",
         "srcloc.jac",
         "transform.jac",
         "type_registry.jac",
         "type_utils.jac",
         "types.jac",
         "uni_pass.jac",
         "unitree.jac"
     ),
     # Seams that stay, each naming what has to land before it goes. Keyed
     # `<module>::<Type>.<method>` exactly as `_seal_demotions` keys them, so
     # an entry reads the same as one in `NATIVE_SEAL_DEMOTION_WAIVERS` --
     # all of these are mirrored there now that `unitree` is in
     # `NATIVE_SEAL_ROOTS`: the unitree/types/type_utils/helpers entries as
     # the families `_CLOSURE_SEAM_WAIVERS` always carried, and the
     # codeinfo/transform/uni_pass entries as the `_CODEINFO_SEAM_WAIVERS`,
     # `_TRANSFORM_SEAM_WAIVERS` and `_UNI_PASS_SEAM_WAIVERS` families that
     # joined it when B4 emptied the hold.
     #
     # A `<field>.__get__` entry is a property. #8074 made accessors lower as
     # methods, so their bodies reach the backend for the first time; before it
     # a property read loaded a data slot nothing ever wrote, which made these
     # invisible rather than absent. A property declared on a non-primary
     # ancestor is re-emitted per concrete class, because its body addresses
     # that class's field offsets -- so one un-lowerable accessor is listed
     # once per class that inherits it, and the reason is shared.
     SEAM_WAIVERS: dict[(str, str)] = {
         "unitree.jac::ModulePath.resolve_relative_path": (
             "Python-only: import resolution runs through "
             "`jac0core.modresolver` (importlib / sys.path / pathlib), which "
             "no native unit can host. Unreachable from a sealed parser -- "
             "every caller is a Python-side pass."
         ),
         "unitree.jac::ModulePath.native_bundled_path": (
             "Python-only: `is_bundled_native_module` / "
             "`resolve_native_module` live in `jac0core.codeinfo`, which can "
             "never share a native unit with `unitree` (LLVM binding and "
             "estree handles, and it imports `unitree` back)."
         ),
         "unitree.jac::Module.annexable_by.__get__": (
             "Python-only: calls `jac0core.bccache.discover_base_file`, which "
             "walks the filesystem. Read by the compile driver, not a parse."
         ),
         "unitree.jac::Import.__jac_detected.__get__": (
             "Python-only, two layers: the coverage reports E5090 on its import "
             "of `jac0core.ext_registry`, one of the plain-Python pre-runtime "
             "modules (with `cache_paths` and `sealed`) the bootstrap loads "
             "before any Jac runtime exists; beneath it every branch resolves "
             "through `ModulePath.resolve_relative_path`, itself waived above."
         ),
         "unitree.jac::Import.is_service_import.__get__": (
             "Python-only: calls `is_service_module_stem` from "
             "`jac0core.service_cut`, which stats and parses `jac.toml` "
             "(`os.path.getmtime` + `tomllib`), memoizes into a module-global "
             "dict, and resolves the project root through "
             "`jac0core.modresolver`. The coverage reports E5092 -- the call "
             "will not lower -- not an E5090 import."
         ),
         "unitree.jac::BuiltinType.lit_value.__get__": (
             "Python-only: indexes `Literal.type_map`, a static dict of "
             "`type` objects, which has no native layout."
         ),
         "unitree.jac::Ellipsis.lit_value.__get__": (
             "Python-only: returns `...`, which has no native value."
         ),
         "types.jac::ClassType.lookup_member_symbol": (
             "Cascade: calls `type_utils.collect_member_syms`, waived below. "
             "Clears with its callee."
         ),
         "types.jac::FunctionType.specialize": (
             "Cascade: calls `type_utils.build_type_var_solution`, waived "
             "below for its `enumerate(...)` for-loop iterable. This is the "
             "seam #8272 made measurable: the importer now learns a "
             "dependency's demotion set before it emits, so the caller "
             "demotes here instead of linking against the name the demotion "
             "renamed away. Clears with its callee."
         ),
         "type_utils.jac::expr_primitive_name": (
             "Python-only: narrows its `prog` to `JacProgram` and reaches "
             "`get_type_evaluator`. `type_evaluator.jac` is not in this unit "
             "and cannot be, so the attribute chain has no layout to walk."
         ),
         "type_utils.jac::class_implements_protocol": (
             "Backend gap -- imported isinstance: `isinstance` against "
             "`UniScopeNode`, whose layout is not reachable from this unit's "
             "root even though `unitree.jac` is a member."
         ),
         "type_utils.jac::doc_of_sym": (
             "Backend gap -- imported isinstance: `isinstance` against "
             "`AstDocNode`, same unreachable-layout shape."
         ),
         "type_utils.jac::completion_item_from_sym": (
             "Cascade: calls `doc_of_sym`, waived above."
         ),
         "type_utils.jac::get_completion_items": (
             "Cascade: calls `completion_item_from_sym`, waived above."
         ),
         "type_utils.jac::completion_kind_from_sym": (
             "Backend gap: a `match` over unitree archetypes; the "
             "`MatchArch` pattern has no native lowering."
         ),
         "type_utils.jac::collect_member_syms": (
             "Cascade: calls `helpers.evaluate_version_condition`, waived "
             "below for its function-local unitree import. Clears with that "
             "import's hoist."
         ),
         "type_utils.jac::compute_mro_linearization": (
             "Backend gap: builds the linearization from a call whose result "
             "the emitter cannot place in expression position."
         ),
         "type_utils.jac::build_type_var_solution": (
             "Backend gap: iterates `enumerate(...)` directly, and a "
             "`FuncCall` is not a lowerable for-loop iterable. `types.jac`'s "
             "`FunctionType.specialize` cascades on it."
         ),
         "type_utils.jac::shadowed_type_var_names": (
             "Backend gap: a comprehension over an element-erased collection, "
             "so the emitter has no layout for the element it binds."
         ),
         "type_utils.jac::build_solution_from_specialized_class": (
             "Backend gap: the same `enumerate(...)` for-loop iterable as "
             "`build_type_var_solution`."
         ),
         "helpers.jac::read_file_with_encoding": (
             "Python-only: `open()` with an encoding keyword. The native lane "
             "refuses the keyword out loud since #8255 rather than lowering a "
             "call that would ignore it."
         ),
         "helpers.jac::normalize_exclude_patterns": (
             "Backend gap: `str.strip`, `.startswith` and `.rstrip` on an "
             "element-erased list member."
         ),
         "helpers.jac::read_jacignore_patterns": (
             "Cascade: calls `normalize_exclude_patterns`, waived above."
         ),
         "helpers.jac::_is_version_info_access": (
             "Python-only: reads unitree through a function-local "
             "`import jaclang.jac0core.unitree as uni`, a bare Python module "
             "import. The local import is what keeps `helpers` out of a "
             "module-level cycle with `unitree`; hoisting it is the clearing "
             "mechanism, and it needs the cycle to be safe first."
         ),
         "helpers.jac::_is_type_checking_ref": (
             "Python-only: same function-local unitree import."
         ),
         "helpers.jac::_extract_version_tuple": (
             "Python-only: same function-local unitree import."
         ),
         "helpers.jac::evaluate_version_condition": (
             "Python-only: same function-local unitree import. This is the "
             "`.pyi` ingestion path -- version-guarded typeshed blocks -- "
             "which no sealed parse reaches."
         ),
         # `transform.jac` and `uni_pass.jac` contribute no entry:
         # `Alert.pretty_print` cleared when the helpers gutter formatting
         # lowered, `is_canceled`/`ice` cleared for the fused prefix (the
         # cancel scalar; ice as the message its callers raise), and the
         # base-chain field wall is down everywhere -- no measured root
         # demotes `__post_init__`/`transform`/`traverse` any more.
         "codeinfo.jac::CodeGenTarget.doc_ir.__get__": (
             "Python-only: lazily imports `compiler.passes.tool.doc_ir`, "
             "the formatter's IR, which stays Python-side. Only the "
             "formatter reads `.doc_ir`; a parse never does."
         ),
         "codeinfo.jac::_func_layout_to_dict": (
             "Backend gap: boxing an optional (`JacOpt`) into an "
             "`any`-valued dict entry."
         ),
         "codeinfo.jac::_inferred_native_path": (
             "Python-only: calls `placement_solver.native_default_path_ok`, "
             "the placement scan -- the driver's ground, never a parse's."
         ),
         "codeinfo.jac::effective_default_codespace": (
             "Python-only: reads `project.config`, jac.toml machinery."
         ),
         "codeinfo.jac::effective_native_closure_cap": (
             "Python-only: the same `project.config` read, behind a "
             "`ContextVar.get` the backend also cannot compare."
         ),
         "codeinfo.jac::install_native_static_init": (
             "Python-only: writes fields on an `any`-typed LLVM "
             "`ExecutionEngine` handle the driver owns."
         ),
         "codeinfo.jac::is_bundled_native_module": (
             "Cascade: calls `native_stdlib_root`, waived below."
         ),
         "codeinfo.jac::is_client_by_location": (
             "Python-only: reads `jaclang.__file__` through a bare Python "
             "module import."
         ),
         "codeinfo.jac::is_native_by_location": (
             "Python-only: same `jaclang.__file__` read."
         ),
         "codeinfo.jac::native_layout_to_dict": (
             "Backend gap: attribute reads on values of a typed dict "
             "inside a dict comprehension, plus the same `any`-box of an "
             "optional as `_func_layout_to_dict`."
         ),
         "codeinfo.jac::native_stdlib_root": (
             "Python-only: reads `jaclang.__file__` to locate the bundled "
             "na_stdlib on disk."
         ),
         "codeinfo.jac::native_wasm_stem": (
             "Backend gap: `os.path.splitext` has no native lowering."
         ),
         "codeinfo.jac::resolve_native_module": (
             "Cascade: `_inferred_native_path` and `native_stdlib_root`, "
             "waived above, plus `os.path.abspath`."
         )
     };

glob _COVERAGE_MEMO: list = [];

"""The full waiver table."""
def _waived_seams -> dict[(str, str)] {
    return dict(SEAM_WAIVERS);
}

"""Compile `unitree.jac` the way `seal_native_artifacts` does, up to the coverage."""
def _unitree_coverage -> tuple[(dict, bool)] {
    # Runs in dev trees AND inside payload lanes that still compile from
    # source. When THIS runtime serves unitree from its own native seal, a
    # source measurement is not expressible: the compile is answered by the
    # sealed artifact, so the coverage would read an empty closure and every
    # assertion below would be vacuous. That build already ran this exact
    # coverage at seal time (seal_demotion_report refuses un-waived seams),
    # which is the invariant this file pins for source lanes.
    if native_artifact_for("jaclang.jac0core.unitree") is not None {
        testskip(
            "unitree is served from this runtime's native seal; the coverage "
            "gated the build via seal_demotion_report"
        );
    }
    if _COVERAGE_MEMO {
        return _COVERAGE_MEMO[0];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(UNITREE_SRC),
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
    result = (coverage, ir is not None and ir.gen.llvm_ir is not None, );
    _COVERAGE_MEMO.append(result);
    return result;
}

"""Coverage seams as `<module>::<Type>.<method>` -> reason."""
def _seams_by_key -> dict[(str, str)] {
    (coverage, _has_ir) = _unitree_coverage();
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(coverage.items()) {
        where = os.path.basename(path);
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


test "unitree's native closure is exactly the measured set" {
    (coverage, _has_ir) = _unitree_coverage();
    seen = tuple(sorted({os.path.basename(p) for p in coverage}));
    assert seen == UNITREE_CLOSURE , (
        f"unitree's native closure changed: {seen} != {UNITREE_CLOSURE}. "
        "A new member has to reach zero seams too before unitree can seal."
    );
}


test "unitree's closure produces native IR" {
    (_coverage, has_ir) = _unitree_coverage();
    assert has_ir , (
        "no LLVM IR for unitree.jac -- the compile aborted before codegen, so "
        "a zero-seam coverage below would mean 'not reached', not 'clean'"
    );
}


test "no un-waived seam in unitree's closure" {
    seams = _seams_by_key();
    waived = _waived_seams();
    unexpected = sorted(
        k
        for k in seams
        if k not in waived
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in unitree's sealed closure:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
}


test "every seam waiver still matches a real seam" {
    seams = _seams_by_key();
    waived = _waived_seams();
    stale = sorted(
        k
        for k in waived
        if k not in seams
    );
    assert not stale , (
        "waived seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {waived[k]}" for k in stale)
    );
}
