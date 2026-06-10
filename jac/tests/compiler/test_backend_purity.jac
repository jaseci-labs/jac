"""Backend purity enforcement (analysis-centralization plan, Phase 10).

Backends (ECMAScript and native code generation) must be pure consumers of
facts computed by the central analysis pipeline (types on `Expr.type`,
symbols via `.sym`, layouts via LayoutRegistry, archetype facts like
`arch_kind`/`event_triggers`). This test statically scans backend sources
for analysis-API usage so no second analyzer grows back.

The allowlist below documents the *current* known violations (remaining
migration debt tracked in analysis-centralization-plan.md). Counts may only
go DOWN: when you remove a violation, lower (or delete) its allowlist
entry; adding a new violation fails this test.
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
     # (relative-path, pattern-name) -> max allowed matching lines.
     # These are existing violations awaiting migration; do not add entries.
     ALLOWLIST: dict[tuple, int] = {
         ("ecmascript/impl/esast_gen_pass.impl.jac", "type_evaluator"): 4,
         ("ecmascript/impl/esast_gen_pass.impl.jac", "symbol_utils"): 3,
         ("ecmascript/impl/esast_gen_pass.impl.jac", "type_tag.tag"): 7,
         ("ecmascript/impl/esast_gen_pass.impl.jac", ".lookup("): 3,
         ("native/na_ir_gen_pass.impl/calls.impl.jac", "symbol_utils"): 1,
         ("native/na_ir_gen_pass.impl/objects.impl.jac", "symbol_utils"): 2,
         ("native/na_ir_gen_pass.impl/core.impl.jac", "type_tag.tag"): 2,
         ("native/na_ir_gen_pass.impl/func.impl.jac", "type_tag.tag"): 12,
         ("native/na_ir_gen_pass.impl/objects.impl.jac", "type_tag.tag"): 6,
         ("native/na_ir_gen_pass.impl/stmt.impl.jac", "type_tag.tag"): 14,
         ("native/na_ir_gen_pass.impl/expr.impl.jac", "type_tag.tag"): 2,
         ("native/na_ir_gen_pass.impl/globals.impl.jac", "type_tag.tag"): 2,

     };

test "backend passes do not re-run analysis" {
    passes_root = Path(jaclang.__file__).parent / "compiler" / "passes";
    compiled = {name: re.compile(pat) for (name, pat) in FORBIDDEN.items()};
    violations: list[str] = [];
    for backend in ("ecmascript", "native") {
        for src in sorted((passes_root / backend).rglob("*.jac")) {
            rel = src.relative_to(passes_root).as_posix();
            text = src.read_text(encoding="utf-8", errors="replace");
            lines = text.splitlines();
            for (name, rx) in compiled.items() {
                count = sum(
                    ( 1
                    for ln in lines
                    if rx.search(ln) )
                );
                allowed = ALLOWLIST.get((rel, name), 0);
                if count > allowed {
                    violations.append(
                        f"{rel}: pattern '{name}' found on {count} line(s), "
                        f"allowed {allowed}. Backends must consume central "
                        "analysis facts (Expr.type, .sym, LayoutRegistry) "
                        "instead of re-running analysis."
                    );
                }
            }
        }
    }
    assert not violations , "\n".join(violations);
}

test "purity allowlist is not stale" {
    # Every allowlist entry must still point at a real file with at least
    # one match; otherwise the entry should be ratcheted down or removed.
    passes_root = Path(jaclang.__file__).parent / "compiler" / "passes";
    compiled = {name: re.compile(pat) for (name, pat) in FORBIDDEN.items()};
    stale: list[str] = [];
    for ((rel, name), allowed) in ALLOWLIST.items() {
        src = passes_root / rel;
        if not src.exists() {
            stale.append(f"{rel}: file no longer exists; remove its entries.");
            continue;
        }
        lines = src.read_text(encoding="utf-8", errors="replace").splitlines();
        count = sum(
            ( 1
            for ln in lines
            if compiled[name].search(ln) )
        );
        if count < allowed {
            stale.append(
                f"{rel}: pattern '{name}' now on {count} line(s) but "
                f"allowlist permits {allowed}; ratchet the entry down."
            );
        }
    }
    assert not stale , "\n".join(stale);
}
