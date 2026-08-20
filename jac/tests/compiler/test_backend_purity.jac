"""Backend purity enforcement (analysis-centralization plan, Phase 10).

Backends (ECMAScript and native code generation) must be pure consumers of
facts computed by the central analysis pipeline (types on `Expr.type`,
symbols via `.sym`, layouts via LayoutRegistry, archetype facts like
`arch_kind`/`event_triggers`). This test statically scans backend sources
for analysis-API usage so no second analyzer grows back.

The relocation plan (jaseci-labs/jaseci#6542) is COMPLETE: MIGRATION_DEBT
is empty. What remains is SANCTIONED - permanent, per-entry-justified
consumption of central APIs and declaration-surface reads at codegen
time. Sanctioned counts are exact in both directions: growth means new
unreviewed analysis crept into a backend (fix the code), shrink means an
entry earned tightening (edit the table). Either way the change is
deliberate and reviewed here.
"""

import re;
import jaclang;
import from pathlib { Path }

# Forbidden analysis patterns (name -> regex matched per source line).
glob FORBIDDEN: dict[str, str] = {
         # Re-running type inference inside a backend.
         "type_evaluator": r"type_evaluator",
         # Re-running call/member resolution helpers inside a backend.
         "symbol_utils": r"symbol_utils",
         # Re-deriving types from annotation AST instead of `Expr.type`.
         "type_tag.tag": r"type_tag[?]?[.]tag",
         # Re-resolving names on scope tables instead of consuming `.sym`.
         ".lookup(": r"[.]lookup[(]",

     },
     # Remaining relocation work: (relative-path, pattern) -> max count.
     # EMPTY by design - the plan is complete. Adding an entry here means a
     # backend grew analysis that belongs in the central pipeline; that is
     # a regression to fix, not debt to record.
     MIGRATION_DEBT: dict[tuple, int] = {},
     # Reviewed permanent consumption: (relative-path, pattern) ->
     # (exact line count, rationale). These are NOT analysis duplication:
     # they are reads of central APIs or of the declaration surface itself,
     # at sites where the declaration IS the fact.
     SANCTIONED: dict[tuple, tuple] = {
         ("ecmascript/impl/esast_gen_pass.impl.jac", "symbol_utils"): (
             6,
             "collect_field_names/symbol_owner_archetype - symbol-FACT "
             "readers over an already-resolved walker symbol. "
             "The former classify_call fallback is deleted (#7418): "
             "call_kind is stamped authoritatively by the required "
             "inference schedule. Plus two client-boundary reads (#7632): "
             "resolve_import_source_module (the delegated body of the "
             "former local _resolve_source_module, now shared with "
             "StaticAnalysisPass) and the classify/report helpers in "
             "_partition_client_import_items - both consume the SOURCE "
             "module's stamped code_context and declaration surface, "
             "facts that exist on no local-tree node. The "
             "symbol_linked_source_module read (#7740) left with the "
             "esast-time pull hook (#7679): cross-module pulls now happen "
             "in the placement solver before codegen, so ES generation "
             "only consumes stamped facts, never the producer. The former "
             "ability_of_symbol read at sv-import stub generation is "
             "deleted (#7760): stubs now consume the InteropBinding "
             "recorded by BoundaryAnalysisPass. Plus "
             "report_client_bare_import_uses at exit_module: client use "
             "of a bare import that resolves to no client-reachable "
             "module is a guaranteed runtime ReferenceError - the "
             "reporter consumes stamped code_context and symbol facts, "
             "shared with StaticAnalysisPass so build-only and "
             "check-only runs agree. Plus client_value_ref_targets / "
             "client_bridged_endpoint at exit_module (#8072): the same "
             "shape one level up - client code naming a module element "
             "that the bundle never binds is a guaranteed runtime "
             "ReferenceError, so the backend asks the central resolver "
             "which references have no client binding and which are "
             "endpoints it must bind a forwarder for. It consumes "
             "stamped code_context, resolved `.sym`, and the declared "
             "access tag; the same resolver drives W6007 in "
             "StaticAnalysisPass, which is the point - the emit path and "
             "the check path must not disagree about what is bound"
         ),
         ("ecmascript/impl/esast_gen_pass.impl.jac", ".lookup("): (
             4,
             "declaration-surface reads: (1) cross-module archetype kind "
             "for OSP lowering (#7948) - _arch_kind_by_name resolves an "
             "imported archetype NAME to its declared node/edge/walker "
             "kind via the module symbol, the exact declaration-IS-the-"
             "fact category; tags derive from stable_osp_tag(name), no "
             "analysis re-run. (2) component PascalCase rename "
             "collision guard checks whether the capitalized name is "
             "already declared in the module - the declared NAME is the "
             "consumed fact, not a resolved type. (3-4) runtime-import "
             "injection guard checks ir_in and the main module (when "
             "different) for a locally declared name before emitting a "
             "@jac/runtime import - the declared NAME is the consumed "
             "fact, not a resolved type. The former sv-import "
             "stub lookup is deleted (#7760): signatures come from the "
             "recorded InteropBinding"
         ),
         ("ecmascript/impl/esast_gen_pass.impl.jac", "type_tag.tag"): (
             9,
             "declaration-surface name reads: param/field type-name maps "
             "for interop payloads, Ref[...] head detection, and the W6005 "
             "Callable-over-RPC guard on endpoint params - the declared "
             "annotation is the consumed fact, not a resolved type"
         ),
         ("native/na_ir_gen/generics.impl.jac", "type_tag.tag"): (
             3,
             "generic-template declared-annotation reads where the "
             "declaration IS the fact: (1) the _solve_generic_call fallback "
             "(a bundled/imported template compiled symtab_ir_only has no "
             "stamped FunctionType, and an uninstantiated template has no "
             "per-callsite resolved type to consume); (2)+(3) "
             "_instantiate_generic_for_target (#7626 A5) matches the "
             "template's declared TypeVar param annotations against the "
             "binding's concrete Callable annotation to derive the "
             "monomorphization solution - the template is uninstantiated, "
             "so the declared annotations are the only TypeVar surface"
         ),
         ("native/na_ir_gen/calls.impl.jac", "symbol_utils"): (
             2,
             "classify_call as the shadowing-aware builtin test for the "
             "`type(None)` isinstance argument form (#6957) - consuming the "
             "central classification instead of re-implementing name "
             "resolution. The former classify_call fallback is deleted "
             "(#7418): call_kind is stamped authoritatively by the required "
             "inference schedule. Plus erased_identity_call_arg (#8223) "
             "and the is_erased_field_marker pair (#8201), declaration-"
             "surface reads on the same terms: whether `cast` or `field` "
             "here is the erasable `typing.cast` / `dataclasses.field` is "
             "answered by the module's own import list and by the call's "
             "own position in a `has` declaration, facts that are "
             "themselves the declaration and live on no analysis product. "
             "The is_builtin_region_name read (#7491) is gone from here and "
             "from stmt.impl.jac, whose entry left this table entirely: the "
             "predicate is pure unitree syntax that was marooned in "
             "symbol_utils, whose own imports reach jac0core/compiler.jac, so "
             "sealing wave 3 hoisted it to the leaf expr_keys.jac. The "
             "backend stopped reaching into the analysis module for it rather "
             "than merely renaming the reach"
         ),
         ("native/na_ir_gen/objects.impl.jac", "symbol_utils"): (
             1,
             "collect_method_names as the central ancestor-method walk over "
             "an already-resolved archetype symbol - a symbol-FACT reader, "
             "not a re-run of member resolution"
         ),
         ("native/na_ir_gen/core.impl.jac", "type_tag.tag"): (
             3,
             "declaration-surface reads at interop layout export, plus the "
             "quiet lowerability probe on imported globs (the py-side "
             "carve-out for dual-codespace modules) which reads the same "
             "declared annotation the adjacent _resolve_jac_type consumes"
         ),
         ("native/na_ir_gen/calls.impl.jac", "type_tag.tag"): (
             1,
             "declaration-surface read of foreign extern signatures: the "
             "clib membrane needs the DECLARED str params/returns of a "
             "foreign call to route them through the JacStr wrap/unwrap "
             "shims (#7870 strings step 2) - the C membrane always "
             "trafficks NUL-terminated char*"
         ),
         ("native/na_ir_gen/func.impl.jac", "type_tag.tag"): (
             4,
             "scalar LLVM materialization from declared clib annotations "
             "at the declaration site - the backend's lowering role "
             "(sysv sig planning + fixed-param lowering, #6707, #6708)"
         ),
         ("native/na_ir_gen/objects.impl.jac", "type_tag.tag"): (
             1,
             "declaration-surface read during archetype field lowering: "
             "the field's declared annotation node is read once into a "
             "local and feeds both the enum-name map and the container "
             "element-key map the sealed layout exports. Keep it one read "
             "- consumers of the annotation are added to the local, never "
             "by reaching for type_tag.tag again"
         ),
         ("native/na_ir_gen/lists.impl.jac", "type_tag.tag"): (
             1,
             "declared-vs-inferred bare list is a declaration-surface "
             "distinction central facts do not carry (the checker stamps "
             "unannotated empties as bare list too); the empty-literal "
             "storage-family decision must key on the explicit annotation"
         ),
         ("native/na_ir_gen/stmt.impl.jac", "type_tag.tag"): (
             7,
             "surface-shape dispatch on declared annotation forms "
             "(assessed train 4: legitimately kept); the "
             "escaping-closure value-hint guard (#7593 item 12), a "
             "presence-only test that fires when NO annotation is "
             "declared - the declaration surface's absence is the "
             "consumed fact, not a re-derived type; plus the generic-"
             "as-value hook (#7626 A5): a presence test and a handoff of "
             "the annotation NODE to _instantiate_generic_for_target, "
             "which needs the declared Callable annotation itself (the "
             "template is uninstantiated, so no resolved type exists)"
         ),

     };

"""Count matching lines per (file, pattern) across both backends."""
def scan_backends -> dict {
    passes_root = Path(jaclang.__file__).parent / "compiler" / "passes";
    compiled = {name: re.compile(pat) for (name, pat) in FORBIDDEN.items()};
    counts: dict = {};
    for backend in ("ecmascript", "native") {
        for src in sorted((passes_root / backend).rglob("*.jac")) {
            if not src.is_file() {
                continue;
            }
            rel = src.relative_to(passes_root).as_posix();
            lines = src.read_text(encoding="utf-8", errors="replace").splitlines();
            for (name, rx) in compiled.items() {
                count = sum(
                    ( 1
                    for ln in lines
                    if rx.search(ln) )
                );
                if count {
                    counts[(rel, name)] = count;
                }
            }
        }
    }
    return counts;
}

test "backend passes do not re-run analysis" {
    counts = scan_backends();
    violations: list[str] = [];
    for ((rel, name), count) in counts.items() {
        allowed = MIGRATION_DEBT.get((rel, name), 0);
        sanc = SANCTIONED.get((rel, name));
        if sanc is not None {
            allowed += sanc[0];
        }
        if count > allowed {
            violations.append(
                f"{rel}: pattern '{name}' found on {count} line(s), "
                f"allowed {allowed}. Backends must consume central "
                "analysis facts (Expr.type, .sym, LayoutRegistry) "
                "instead of re-running analysis. If this consumption is "
                "genuinely a central-API or declaration-surface read, "
                "sanction it HERE with a rationale - in review."
            );
        }
    }
    assert not violations , "\n".join(violations);
}

test "sanctioned consumption is exact" {
    # Both directions are deliberate edits: growth is unreviewed analysis,
    # shrink means the entry earned tightening.
    counts = scan_backends();
    stale: list[str] = [];
    for ((rel, name), (allowed, _why)) in SANCTIONED.items() {
        actual = counts.get((rel, name), 0);
        if actual != allowed {
            stale.append(
                f"{rel}: pattern '{name}' now on {actual} line(s) but "
                f"SANCTIONED records {allowed}; update the entry (and its "
                "rationale) deliberately."
            );
        }
    }
    for ((rel, name), allowed) in MIGRATION_DEBT.items() {
        actual = counts.get((rel, name), 0);
        if actual < allowed {
            stale.append(
                f"{rel}: pattern '{name}' now on {actual} line(s) but "
                f"MIGRATION_DEBT permits {allowed}; ratchet the entry down."
            );
        }
    }
    assert not stale , "\n".join(stale);
}
