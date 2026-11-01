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
     MIGRATION_DEBT: dict[tuple[str, str], int] = {},
     # Reviewed permanent consumption: (relative-path, pattern) ->
     # (exact line count, rationale). These are NOT analysis duplication:
     # they are reads of central APIs or of the declaration surface itself,
     # at sites where the declaration IS the fact.
     SANCTIONED: dict[tuple[str, str], tuple[int, str]] = {
         ("es/esast_gen_pass.jac", "symbol_utils"): (
             1,
             "return_type_is_jsx (#8314), wired module-wide by archwire.jac for "
             "the call and declaration impls: reads the declared return "
             "annotation to pick a component's call ABI and to record a "
             "component export; the declaration is the fact, and the type "
             "checker keys component-hood off the same predicate so the two "
             "cannot disagree"
         ),
         ("es/esast_gen_pass.impl/calls.impl.jac", "symbol_utils"): (
             3,
             "symbol-FACT readers over already-resolved symbols at call "
             "lowering: resolve_import_source_module (#7632, the delegated "
             "body of the former local _resolve_source_module, shared with "
             "StaticAnalysisPass) consumes the SOURCE module's stamped "
             "code_context; ability_of_symbol reads the declared ability "
             "behind a resolved callee symbol; client_value_ref_targets / "
             "client_bridged_endpoint (#8072) ask the central resolver "
             "which client references have no bundle binding and which "
             "are endpoints needing a forwarder - the same resolver "
             "drives W6007 in StaticAnalysisPass, so the emit path and the "
             "check path cannot disagree about what is bound. The former "
             "classify_call fallback is deleted (#7418): call_kind is "
             "stamped authoritatively by the required inference schedule"
         ),
         ("es/esast_gen_pass.impl/module.impl.jac", "symbol_utils"): (
             1,
             "report_client_bare_import_uses at exit_module: client use of "
             "a bare import that resolves to no client-reachable module is "
             "a guaranteed runtime ReferenceError - the reporter consumes "
             "stamped code_context and symbol facts, shared with "
             "StaticAnalysisPass so build-only and check-only runs agree"
         ),
         ("es/esast_gen_pass.impl/imports.impl.jac", "symbol_utils"): (
             1,
             "the classify/report helpers in _partition_client_import_items "
             "(#7632) consume the SOURCE module's stamped code_context and "
             "declaration surface, facts that exist on no local-tree node. "
             "The former ability_of_symbol read at sv-import stub "
             "generation is deleted (#7760): stubs consume the "
             "InteropBinding recorded by BoundaryAnalysisPass"
         ),
         ("es/esast_gen_pass.impl/osp.impl.jac", "symbol_utils"): (
             2,
             "collect_field_names/symbol_owner_archetype - symbol-FACT "
             "readers over an already-resolved walker symbol when building "
             "the spawn argument object and deriving the endpoint identity from "
             "the resolved walker declaration. The symbol_linked_source_module "
             "read (#7740) left with the esast-time pull hook (#7679): "
             "cross-module pulls now happen in the placement solver before "
             "codegen, so ES generation only consumes stamped facts"
         ),
         ("es/esast_gen_pass.impl/calls.impl.jac", ".lookup("): (
             1,
             "component PascalCase rename collision guard checks whether "
             "the capitalized name is already declared in the module - the "
             "declared NAME is the consumed fact, not a resolved type. The "
             "former sv-import stub lookup is deleted (#7760): signatures "
             "come from the recorded InteropBinding"
         ),
         ("es/esast_gen_pass.impl/osp.impl.jac", ".lookup("): (
             1,
             "cross-module archetype kind for OSP lowering (#7948) - "
             "_arch_kind_by_name resolves an imported archetype NAME to its "
             "declared node/edge/walker kind via the module symbol, the "
             "exact declaration-IS-the-fact category; tags derive from "
             "stable_osp_tag(name), no analysis re-run"
         ),
         ("native/impl/foreign.impl.jac", "type_tag.tag"): (
             4,
             "declared-annotation name reads for the foreign (clib) ABI "
             "surface: declared_type_name over field and param annotations "
             "where the declaration IS the wire fact. Formerly outside this "
             "audit at compiler/targets/; absorbed into backends/native by "
             "the #8681 reorg with its consumption unchanged"
         ),
         ("es/esast_gen_pass.impl/calls.impl.jac", "type_tag.tag"): (
             3,
             "declaration-surface name reads: the param type-name map for "
             "interop payloads and the W6005 Callable-over-RPC guard on "
             "endpoint params - the declared annotation is the consumed "
             "fact, not a resolved type"
         ),
         ("es/esast_gen_pass.impl/view.impl.jac", "type_tag.tag"): (
             2,
             "Ref[...] head detection on has-var annotations for client "
             "state lowering - the declared annotation is the consumed fact"
         ),
         ("es/esast_gen_pass.impl/osp.impl.jac", "type_tag.tag"): (
             3,
             "field type-name map for the spawn argument payload - the "
             "declared annotation is the consumed fact, not a resolved type"
         ),
         ("native/mir/impl/lower.impl.jac", "type_evaluator"): (
             5,
             "MIR lowering reads the type the checker recorded for an "
             "already-resolved symbol (get_type_of_symbol): a function's or "
             "callee's FunctionType for its signature and C-call ABI, a "
             "parameter's or name's declared type, and a C struct field's "
             "type. Each read is of a symbol the central pipeline resolved "
             "and typed; none asks the evaluator to infer an expression"
         ),
         ("native/mir/impl/lower.objects.impl.jac", "type_evaluator"): (
             1,
             "the method signature read for an archetype's methods, the same "
             "get_type_of_symbol read of a resolved method symbol that "
             "lower.impl.jac makes for functions"
         ),

     };

"""Count matching lines per (file, pattern) across both backends. A module
sealed by archwire.jac declares its imports there instead of in its sources, so
each wire whose provider matches counts as one line of the file its import
lands in: the file defining the wire's scope, or the head module."""
def scan_backends -> dict[tuple[str, str], int] {
    passes_root = Path(jaclang.__file__).parent / "compiler" / "backends";
    compiled = {name: re.compile(pat) for (name, pat) in FORBIDDEN.items()};
    counts: dict[tuple[str, str], int] = {};
    for backend in ("es", "native") {
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
            for ((w_rel, name), n) in wired_lines(src, passes_root, compiled).items() {
                counts[(w_rel, name)] = counts.get((w_rel, name), 0) + n;
            }
        }
    }
    return counts;
}

"""Wires into the module headed by `src`, attributed to the file whose code
receives each generated import."""
def wired_lines(
    src: Path, passes_root: Path, compiled: dict[str, re.Pattern]
) -> dict[tuple[str, str], int] {
    import from jaclang.compiler.driver.wiring { wiring_for_path }
    import from jaclang.compiler.driver.bccache { discover_annex_files }
    out: dict[tuple[str, str], int] = {};
    spec = wiring_for_path(str(src));
    module = spec.module_name(str(src)) if spec is not None else None;
    if spec is None or module is None {
        return out;
    }
    head_rel = src.relative_to(passes_root).as_posix();
    targets: dict[str, tuple[str, str]] = {};
    module_text = "";
    for f in [str(src), *discover_annex_files(str(src), ".impl.jac")] {
        f_rel = Path(f).relative_to(passes_root).as_posix();
        text = Path(f).read_text(encoding="utf-8", errors="replace");
        module_text += "\n".join(
            [
                ln
                for ln in text.splitlines()
                if not ln.startswith((" ", "\t"))
            ]
        );
        for m in re.finditer(
            r"^(?:impl|def)\s+([\w.]+)[^\n]*\n(.*?)^\}", text, re.M | re.S
        ) {
            targets.setdefault(m.group(1), (f_rel, m.group(2)));
        }
    }
    for wire in spec.consumer_wires(module) {
        scope = ".".join(spec.consumer_scope(module, wire));
        dest = head_rel;
        body = module_text;
        best = -1;
        for (target, (t_rel, t_body)) in targets.items() {
            if scope and (scope == target or scope.startswith(target + ".")) {
                if len(target) > best {
                    best = len(target);
                    dest = t_rel;
                    body = t_body;
                }
            }
        }
        if f"import from {spec.import_name(wire.provider)} " in body {
            continue;
        }
        for (name, rx) in compiled.items() {
            if rx.search(wire.provider) {
                out[(dest, name)] = out.get((dest, name), 0) + 1;
            }
        }
    }
    return out;
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
