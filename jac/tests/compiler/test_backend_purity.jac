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
             3,
             "collect_field_names/symbol_owner_archetype - symbol-FACT "
             "readers over an already-resolved walker symbol; and "
             "ability_of_symbol, the shared central helper (deduped from a "
             "former local _ability_from_symbol) used to resolve a SOURCE "
             "module's exported ability at sv-import client-stub generation. "
             "The former classify_call fallback is deleted (#7418): "
             "call_kind is stamped authoritatively by the required "
             "inference schedule"
         ),
         ("ecmascript/impl/esast_gen_pass.impl.jac", ".lookup("): (
             2,
             "declaration-surface reads: (1) sv-import client stub "
             "generation resolves the SOURCE module's exported ability - "
             "no fact on the local tree exists; (2) component PascalCase "
             "rename collision guard checks whether the capitalized name "
             "is already declared in the module - the declared NAME is "
             "the consumed fact, not a resolved type"
         ),
         ("ecmascript/impl/esast_gen_pass.impl.jac", "type_tag.tag"): (
             7,
             "declaration-surface name reads: param/field type-name maps "
             "for interop payloads and Ref[...] head detection - the "
             "declared NAME is the consumed fact, not a resolved type"
         ),
         ("native/na_ir_gen_pass.impl/calls.impl.jac", "symbol_utils"): (
             1,
             "classify_call as the shadowing-aware builtin test for the "
             "`type(None)` isinstance argument form (#6957) - consuming the "
             "central classification instead of re-implementing name "
             "resolution. The former classify_call fallback is deleted "
             "(#7418): call_kind is stamped authoritatively by the required "
             "inference schedule"
         ),
         ("native/na_ir_gen_pass.impl/objects.impl.jac", "symbol_utils"): (
             1,
             "classify_call fallback for synthesized constructor calls"
         ),
         ("native/na_ir_gen_pass.impl/core.impl.jac", "type_tag.tag"): (
             2,
             "declaration-surface reads at interop layout export"
         ),
         ("native/na_ir_gen_pass.impl/func.impl.jac", "type_tag.tag"): (
             4,
             "scalar LLVM materialization from declared clib annotations "
             "at the declaration site - the backend's lowering role "
             "(sysv sig planning + fixed-param lowering, #6707, #6708)"
         ),
         ("native/na_ir_gen_pass.impl/objects.impl.jac", "type_tag.tag"): (
             1,
             "declaration-surface read during archetype field lowering"
         ),
         ("native/na_ir_gen_pass.impl/stmt.impl.jac", "type_tag.tag"): (
             4,
             "surface-shape dispatch on declared annotation forms "
             "(assessed train 4: legitimately kept)"
         ),

     };

"""Count matching lines per (file, pattern) across both backends."""
def scan_backends -> dict {
    passes_root = Path(jaclang.__file__).parent / "compiler" / "passes";
    compiled = {name: re.compile(pat) for (name, pat) in FORBIDDEN.items()};
    counts: dict = {};
    for backend in ("ecmascript", "native") {
        for src in sorted((passes_root / backend).rglob("*.jac")) {
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
