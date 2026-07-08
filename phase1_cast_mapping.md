# Phase 1 — `CMapper` → `CastBuildPass` mapping

Concrete port table for
[jaseci-labs/jaseci#7145](https://github.com/jaseci-labs/jaseci/issues/7145)
Leg 1 (Lift). Source of truth for the `proc_*` coverage of
`compiler/passes/main/cast_load_pass.jac`, modeled method-for-method on
`PyastBuildPass` (`compiler/passes/main/pyast_load_pass.jac`).

## Phase 1 checklist

Ordered to be landable incrementally; each step is testable against the ported
fixtures before the next.

1. **Vendor.** Trim `pycparser` (drop `c_generator.py` + `_ast_gen`; **keep**
   `fake_libc_include` — the [#6973] omission that broke the default include
   path) and `pcpp` under `jaclang/vendor/`; remove the `pcpp` pip-install from
   `launcher/payload.zig`.
2. **Front-end.** Create `compiler/cfront/` and populate it per §E: move the four
   truly-pure files intact (import-path rewrites only), and move
   `c_common.jac`/`enum_prepass.jac` with the small tag-system refactors §E
   specifies (relocate `BinKind`; swap `Idiom` verdicts for a local `EnumShape`).
3. **AST wrapper.** Add `uni.CModuleAst(EmptyToken)` mirroring `PythonModuleAst`
   (`unitree.jac:1718`) — **three** edits, not one: (a) the `obj` decl in
   `jac0core/unitree.jac` (fields `orig_src`/`file_path` `by postinit`, wrapping
   the pycparser `FileAST`); (b) its `.init` impl in
   `jac0core/impl/unitree.impl.jac` (mirror `PythonModuleAst.init`,
   `unitree.impl.jac:2544`); and (c) the two matching `jac0core/jir_registry.jac`
   entries — a `NodeSpec(type_idx=<next>, class_name="CModuleAst", ...)` (mirror
   `PythonModuleAst` at `jir_registry.jac:1331`) plus the name→idx mapping
   (`"PythonModuleAst": 117` at `jir_registry.jac:1796`), allocating the next free
   `type_idx`. Only skip (c) if you verify wrapper nodes are intentionally
   excluded by the registry-generation path.
4. **Lifter.** Implement `CastBuildPass` (`compiler/passes/main/cast_load_pass.jac`)
   as `Transform[uni.CModuleAst, uni.Module]`: §A first (direct ports, gets the
   bulk of fixtures green), then §B (`for`/`enum`/`switch`/`do-while` — the
   ex-splice constructs). §C is *not written* — it's the code that disappears.
   The pass owns its own `convert(c_node)` dispatcher (mirror
   `PyastBuildPass.convert`, `pyast_load_pass.impl.jac:2163`) — `Transform` does
   **not** auto-dispatch pycparser nodes. `PyastBuildPass` dispatches on
   `pascal_to_snake(type(nd).__name__)`, which mangles all-caps pycparser node
   names: `FileAST` → `proc_file_a_s_t` and `ID` → `proc_i_d` (verified against
   `helpers.pascal_to_snake`). So `convert` needs an explicit override map
   (`{"FileAST": "proc_file_ast", "ID": "proc_id"}`) for those two acronym nodes,
   falling back to `pascal_to_snake` for the rest.
5. **Diagnostics.** Register the paired `E42xx`/`W42xx` code set (§D.1) and the
   `emit_c_diag` helper (§D.2) *before* porting §A/§B, since severity and lenient
   mode are structural (invariant 2), not a late wiring step.
6. **Command.** Reimplement `jac c2jac` in `cli/commands/transform.jac` as
   lift + `unparse()`, rendering diagnostics as the `# c2jac:` report header and
   inline flags. **`jac c2jac` constructs the pass with `lenient_c=True`** — the
   transpile command stays best-effort/reporting (fidelity gaps become `W42xx`
   flags in the output, never a hard stop), even though the #7145 *ingestion*
   path (`import` of C) is strict-by-default (`E42xx`, `blocks_codegen`). A
   `--strict-c` flag on `c2jac` opts into the strict `E42xx` behavior for users
   who want the transpile to fail on any unfaithful lowering.

Phase-0 prerequisites (land first, standalone): `pyast_load_pass` `ctrl_loc`
fix for `break`/`continue`, CLI `_norm_dest` fix for hyphenated `APPEND` dests,
and porting the ~50 fixtures from `jac/tests/compiler/c2jac/fixtures/`.

## Implementation invariants

Non-negotiables for `CastBuildPass`, ahead of the tables:

1. **C-node locations are independent of Uni construction.** `Transform.emit`
   locates a diagnostic via `self.cur_node` or a `UniNode` `node_override`
   (`transform.jac:57`) — it has **no** way to accept a pycparser node. The pass
   must own an `emit_c_diag(c_node, num, anchor)` helper (see §D.2) that either
   anchors on a real Uni node's existing `.loc` or, when no node exists yet,
   builds a synthetic `Token` (hence a `CodeLocInfo`) from the pycparser `coord`.
   Every faithfulness call site routes through this, not raw `emit`.
2. **Severity is encoded in `DiagnosticInfo`, so `--lenient-c` is not an
   afterthought.** `emit()` reads `diag.severity` (`diagnostics.jac:14`); you
   cannot downgrade error→warning at the call. Register **paired** codes per
   concern (an `E42xx` error + `W42xx` warning sharing one number) and select by
   the pass's `lenient` flag inside `emit_c_diag` (§D.1).
3. **Per row, distinguish "logic carries over" from "node construction
   rewritten."** Column **Port** below: `retarget` = build a different node
   around unchanged decision logic; `rewrite` = the method currently emits
   composite Python AST (`Subscript`/`List`/`BinOp`/`ListComp`) that
   `PyastBuildPass` then normalizes — direct Uni construction is a genuine
   rewrite, not a swap.
4. **Casts and pointer idioms are classified, not assumed.** Each is exactly one
   of **faithful** (silent), **lossy-with-diagnostic** (emit + best-effort
   lower), or **unliftable** (emit error / surrogate). §F is the authority; the
   §A/§B `notes` must not contradict it.

Target uni nodes below are the *confirmed* return types of the analogous
`PyastBuildPass.proc_*` — so each `retarget` row is "mirror the pyast proc, fed
from a C node." Rows with **no pyast analog** are the constructs that previously
took the placeholder+splice detour; they now build the uni node directly.

## A. Constructs with a pyast analog

**Port** column: `retarget` = decision logic unchanged, build a different node;
`rewrite` = currently emits composite Python AST that `PyastBuildPass`
normalizes, so direct Uni construction is a real rewrite (invariant 3).

| pycparser node | current `CMapper` method | new `proc_*` | target uni node | pyast analog | Port | notes |
|---|---|---|---|---|---|---|
| `FileAST` | `c_FileAST` | `proc_file_ast` | `uni.Module` | `proc_module` | retarget | drop the `ast3.Module` wrapper |
| `FuncDef` | `c_FuncDef` | `proc_func_def` | `uni.Ability` | `proc_function_def` | rewrite | builds `ast3.arguments`/`arg`; rebuild as `uni` param nodes + signature |
| `Compound` | `c_Compound` | `proc_compound` | `list[uni.CodeBlockStmt]` | (inline in pyast) | retarget | pure fan-out via `_conv_stmts` |
| `Decl` | `c_Decl` / `_decl_struct_var` | `proc_decl` | `uni.Assignment` | `proc_ann_assign` | rewrite | qual/storage logic intact, but `AnnAssign`+`Name`+ann construction rebuilt; enum branch → §B |
| `Assignment` | `c_Assignment` | `proc_assignment` | `uni.Assignment` | `proc_assign` | rewrite | chained-assign walk + list-bound logic intact; `Assign`/`AugAssign`/`Name` construction rebuilt |
| `Struct` | `c_Struct` / `_struct_classdef` | `proc_struct` | `uni.Archetype` (obj) | `proc_class_def` | rewrite | `ClassDef`+`AnnAssign` fields → `uni` archetype + has-vars |
| `Typedef` | `c_Typedef` | `proc_typedef` | `uni.Archetype` / `uni.Assignment` | `proc_class_def` / `proc_assign` | rewrite | struct-typedef → obj; scalar typedef → alias assign |
| `ArrayDecl` | `_decl_array` | `proc_array_decl` | `uni.Assignment` | `proc_ann_assign` | **rewrite** | builds `Subscript`+`List`+`BinOp`+`ListComp` (`declarations.impl.jac:342`); each needs a `uni` equivalent (`AtomTrailer`/`ListVal`/`BinaryExpr`/comprehension) |
| `If` | `c_If` | `proc_if` | `uni.IfStmt` | `proc_if` | retarget | list-bound merge across branches intact |
| `While` | `c_While` | `proc_while` | `uni.WhileStmt` | `proc_while` | retarget | `collect_lb_kills` dataflow intact |
| `TernaryOp` | `c_TernaryOp` | `proc_ternary_op` | `uni.IfElseExpr` | `proc_if_exp` | retarget | — |
| `Return` | `c_Return` | `proc_return` | `uni.ReturnStmt` | `proc_return` | retarget | null-ptr→`None` logic intact |
| `Break` | `c_Break` | `proc_break` | `uni.CtrlStmt` | `proc_break` | retarget | ctrl_loc token fix is the Phase-0 cherry-pick |
| `Continue` | `c_Continue` | `proc_continue` | `uni.CtrlStmt` | `proc_continue` | retarget | ″ |
| `EmptyStatement` | `c_EmptyStatement` | `proc_empty_statement` | `uni.Semi` | `proc_pass` | retarget | — |
| `BinaryOp` | `c_BinaryOp` / `_binop_operand` | `proc_binary_op` | `uni.BinaryExpr` | `proc_bin_op` | retarget | `C_BINOPS` map + operand-prim logic intact |
| `UnaryOp` | `c_UnaryOp` / `_inc_dec_stmt` / `_pre_incdec_walrus` | `proc_unary_op` | `uni.UnaryExpr` | `proc_unary_op` | **rewrite** | `++`/`--`→`AugAssign`/walrus (`NamedExpr`+`BinOp`) rebuilt as `uni` aug-assign / walrus |
| `ID` | `c_ID` | `proc_id` | `uni.Name` | `proc_name` | retarget | — |
| `Constant` | `c_Constant` | `proc_constant` | `uni.Literal` (`Int`/`Float`/`String`) | `proc_constant` | retarget | int/float/char/string parsing intact |
| `StructRef` | `c_StructRef` | `proc_struct_ref` | `uni.AtomTrailer(is_attr=True)` | `proc_attribute` | retarget | `a.b` and `a->b` → `AtomTrailer(target, right=Name, is_attr=True)`; pointer split → §F |
| `ArrayRef` | `c_ArrayRef` | `proc_array_ref` | `uni.AtomTrailer(is_attr=False, right=IndexSlice)` | `proc_subscript` | retarget | `a[i]` → `AtomTrailer(target=a, right=IndexSlice([Slice(start=i)], is_range=False))` |
| `InitList` | `c_InitList` / `c_NamedInitializer` | `proc_init_list` | `uni.ListVal` | `proc_list` | **rewrite** | builds `List`/`Dict`+designators; rebuild as `uni.ListVal` |
| `ExprList` | `c_ExprList` | `proc_expr_list` | stmt-sequence (clause) / diagnostic (expr) | — | rewrite | see §F — **not** `TupleVal`; comma-op ≠ tuple |
| `Cast` | `c_Cast` | `proc_cast` | lowered operand (elided) | — | retarget | see §F — scalar cast **elided + diagnosed** today; do **not** silently introduce `int(x)` |
| `FuncCall` | `c_FuncCall` / `_malloc_array` / `_realloc_elide` | `proc_func_call` | `uni.FuncCall` | `proc_call` | **rewrite** | idiom matchers stay in `cfront/c_idioms`; `Call`/`Name`/args construction rebuilt as `uni.FuncCall` params |

## B. Constructs with no pyast analog (were placeholder+splice; now direct build)

These are the reason the two-hop needed `directir.jac` + `splice.jac`. In
direct-lift they are ordinary `proc_*` returns. The node-building logic exists
today in **two** places, not one: `uni_builder.jac` builds only the **enum**
nodes; the **For** promotion (`WhileStmt`+iter → `IterForStmt`) lives in
`splice._promote_for` (`splice.jac:28`). Both move inline into the lifter.

| pycparser node | current path | new `proc_*` | target uni node | was |
|---|---|---|---|---|
| `For` | `c_For` (+ `_for_*` helpers) → `_directir_placeholder` → `splice._promote_for` | `proc_for` | `uni.IterForStmt` (promotable) / `uni.WhileStmt` (desugar) | placeholder in a `WhileStmt`, spliced to `IterForStmt` post-hoc |
| `Enum` | `c_Enum` → `_directir_placeholder` → splice | `proc_enum` | `uni.Enum` / `uni.GlobalVars` consts | placeholder, real enum built by `CUniBuilder`, spliced in |
| `DoWhile` | `c_DoWhile` (pyast `while True{…break}`) | `proc_do_while` | `uni.WhileStmt` | *no splice, but* built via pyast; now emit `uni.WhileStmt` directly |
| `Switch` | `c_Switch` (pyast if/elif chain) | `proc_switch` | `uni.SwitchStmt` (safe) / nested `uni.IfStmt` (unsafe) | ″ built via pyast; now direct |

The `_for_*` faithfulness computation (promotable check, cond-lossy, dataflow
enter/merge) and `switch_is_safe`/`has_loop_continue` analysis carry over
verbatim — they feed the diagnostic emits in §D instead of the tag table. The
`proc_for` slot construction and the cast/pointer fidelity classes are pinned in
§F.

**Switch target — resolve the ambiguity: `uni.SwitchStmt` exists.** UniIR *does*
carry a native switch shape (`uni.SwitchStmt`/`SwitchCase`, `unitree.jac:1379`),
which is exactly the direct-lift target #7145 motivates. So `proc_switch` is a
two-way choice gated by the already-ported `switch_is_safe`/`has_loop_continue`
analysis, **not** a blanket if/elif desugar:

- **Safe switch** (no fall-through, no `continue`-into-loop hazard, cases are
  `MatchPattern`-expressible constants) → build `uni.SwitchStmt` directly. This
  is the faithful path and emits nothing.
- **Unsafe switch** (fall-through, impure/re-evaluated selector, or a case the
  pattern shape can't hold) → keep the nested `uni.IfStmt` desugar **and** emit
  `4202`. The if/elif chain is the best-effort lowering, flagged as lossy.

The current transpiler only ever produced the if/elif chain (it had no direct-IR
switch); adopting `uni.SwitchStmt` for the safe case is a genuine fidelity gain
this port unlocks, not a like-for-like carry-over.

## C. Deleted outright (two-hop compensation — no port)

| item | file | why it evaporates |
|---|---|---|
| `SLOT_SENTINEL`, `is_slot_placeholder`, `slot_id_of` | `directir.jac` (whole) | placeholder protocol only bridged pyast→uni |
| `_promote_for`, `_do_splice`, `_hoist_to_module_body`, `_replace_pair_in_list` | `splice.jac` (whole) | post-hoc tree surgery; direct build has nothing to splice |
| `_directir_placeholder`, `_alloc_slot`, `slot_map`, `_next_slot` | `core.impl.jac` | placeholder allocation |
| `_stamp`, `_stamp_manual` | `core.impl.jac` | pyast `lineno/col_offset/end_*` stamping; uni tokens get positions at build |
| `CUniBuilder` (build-then-splice pass) | `uni_builder.jac` | node-building logic folds into `proc_for`/`proc_enum`; the pass shell dies |
| `has_synthesized_tokens` field + normalize back-fill | `unitree.jac`, `jir_registry.jac`, `normalize_pass.impl.jac` | print-source plumbing; not needed for ingestion |

## D. Tier system → diagnostics (same analysis, new sink)

Every `_mark_tier_b(c_node, reason)` call site already knows a construct is lossy
and why — that analysis survives; only the *sink* changes. But the sink is not a
drop-in: `Transform.emit(diag, node_override, **kwargs)` (`transform.jac:57`)
takes a **registered `DiagnosticInfo`** and locates via `self.cur_node` or a
`UniNode` override — it **cannot** accept a pycparser node, and severity is fixed
in the `DiagnosticInfo` (`diagnostics.jac:14`). So two pieces of design are
required.

**D.1 — Registered diagnostics in the `4200` band.** The existing registry
already encodes severity by prefix (`E`=error via `_err`, `W`=warning via
`_warn`, `diagnostics.jac:55-68`) — so the "paired code" the design needs is just
the **same number under both prefixes**. The `4200` band is **unused by both `E`
and `W`** and is not claimed by any pending roadmap. Note the `40xx` band is
**not** free despite the registry not yet defining those codes: the diagnostics
test suite reserves `E/W 4001-4010` for the Phase-7 *import* diagnostics
(`tests/compiler/passes/main/test_new_diagnostics.jac:848-865`, "PHASE 7: IMPORT
DIAGNOSTICS", INFRA-6 import graph). Allocating C-interop there would collide
with that milestone, so this plan claims `4200` instead (existing occupied
bands: E `1xx/1xxx/2xxx/3012/40xx-reserved/5xxx/9xxx`, W
`60s/1xxx/2xxx/3xxx/40xx-reserved/5xxx/6xxx`). Register these in `diagnostics.jac` alongside the rest (central
registry, same as the `E5xxx` codegen block); the strict `E42xx` carry
`blocks_codegen=True` for the Phase-2 ingestion path, the lenient `W42xx` do not.

`emit_c_diag` picks the `E`-twin (strict, default) or `W`-twin (lenient) of one
number by `self.lenient_c`. Every code maps 1:1 to an existing `_mark_tier_b`
call site:

| # | strict / lenient | category | concern (current call site) |
|---|---|---|---|
| 4201 | `E4201`/`W4201` | SEMANTIC | scalar cast elided — representation-changing conversion not applied (`expressions.impl.jac:273`) |
| 4202 | `E4202`/`W4202` | SEMANTIC | switch fall-through not modelled / impure selector re-evaluated (`control_flow.impl.jac:103`) |
| 4203 | `E4203`/`W4203` | SEMANTIC | do-while `continue` skips the post-body condition test (`control_flow.impl.jac:57`) |
| 4204 | `E4204`/`W4204` | SEMANTIC | comma expression — leading operand side effects dropped (`expressions.impl.jac:262`) |
| 4205 | `E4205`/`W4205` | SEMANTIC | `volatile` qualifier dropped (`declarations.impl.jac:135`) |
| 4206 | `E4206`/`W4206` | SEMANTIC | function-local `static` loses cross-call persistence (`declarations.impl.jac:131`) |
| 4207 | `E4207`/`W4207` | SEMANTIC | variadic `...` → `*args`; `va_list`/`va_arg` not modelled (`declarations.impl.jac:46`) |
| 4208 | `E4208`/`W4208` | SEMANTIC | C-`for` not faithfully lowered — body/cond/`continue`-skips-step (`control_flow.impl.jac:355`) |
| 4209 | `E4209`/`W4209` | SEMANTIC | designated initializer `.field=` — field name dropped, emitted positionally (`expressions.impl.jac`) |
| 4210 | `E4210`/`W4210` | SYNTAX | numeric literal unparsed — emitted as string placeholder (`expressions.impl.jac` `c_Constant`) |
| 4211 | `E4211`/`W4211` | SYNTAX | constant of unrecognized type — emitted as string placeholder (`expressions.impl.jac` `c_Constant`) |
| 4290 | `E4290`/`W4290` | SEMANTIC | **unliftable construct** — no faithful Jac lowering; surrogate/hole node (`_surrogate_*`, e.g. complex `&`/`*` at `expressions.impl.jac:102,109`) |

```
# in diagnostics.jac, after the E5xxx/W-codegen block:
glob E4201 = _err ("E4201", Category.SEMANTIC,
                   "cast to `{target}` elided — {detail}", blocks_codegen=True),
     E4202 = _err ("E4202", Category.SEMANTIC, "switch fall-through not modelled: {detail}", blocks_codegen=True),
     # ... E4203..E4211, then the catch-all:
     E4290 = _err ("E4290", Category.SEMANTIC,
                   "C construct `{ctype}` has no faithful Jac lowering — emitted as a placeholder",
                   blocks_codegen=True);
glob W4201 = _warn("W4201", Category.SEMANTIC, "cast to `{target}` elided — {detail}"),
     # ... W4202..W4211, W4290  (same templates, warning severity, no blocks_codegen)
     W4290 = _warn("W4290", Category.SEMANTIC,
                   "C construct `{ctype}` has no faithful Jac lowering — emitted as a placeholder");
```

**D.2 — `emit_c_diag` helper on `CastBuildPass`.** The single choke point every
former `_mark_tier_b`/`_surrogate` call routes through. The helper reads two pass
fields, added to the `CastBuildPass` shape:

- `orig_src: uni.Source` — the C translation unit's `Source`, passed to every
  synthesized anchor `Token` (mirrors `CUniBuilder.src`).
- `lenient_c: bool` — selects the `W`-twin (lenient, `jac c2jac` default) vs. the
  `E`-twin (strict, ingestion / `--strict-c`). Set once at construction.
- `c_diag_records: list[tuple[str, str, int]]` — the pass's **own** side ledger of
  `(code, formatted_msg, first_line)`, feeding the `# c2jac:` report header and
  inline flags. This is required because `Transform.emit` **returns only `bool`**
  (`transform.impl.jac`) — it appends an `Alert` to `errors_had`/`warnings_had`
  but hands nothing back to the caller. Rather than reach into `errors_had[-1]`
  (fragile, and empty when the diag is suppressed), `emit_c_diag` formats the
  message itself via `diag.format_message(**kw)` (the identical call `emit` makes
  internally) and appends its own record.

**Location construction — the load-bearing detail.** `Transform.emit` reads
**only** `node_override.loc` (`transform.impl.jac:138`), and `CodeLocInfo`
(`codeinfo.jac:251`) is built from two `Token`s — it is *not* a bare
`(line, col)` pair. So there is a real "how does a pycparser coord become a
`.loc`" step, and if it is left implicit implementers will recreate the old
`_stamp` fiction under a new name. The plan pins it explicitly:

- A `Token` **is** a `UniNode` (`unitree.jac:1490`, `obj Token(UniNode)`) and
  carries `_is_synthetic: bool` plus `orig_src`/`line`/`col`/`pos` slots. A
  `UniNode`'s `loc` is `by postinit`, derived from its `kid` tokens via
  `resolve_tok_range` (`unitree.jac:41`); for a lone `Token`, that range is the
  token itself. So a single synthetic `Token` is a complete, locatable
  `node_override`.
- This is the **exact pattern `CUniBuilder._name_node`/`_int_node` already use**
  (`uni_builder.jac:17-44`): `coord_of(c_node)` → `(line, col)`, then build a
  token with `line=end_line=line`, `col_start=col`, `col_end=col+len(text)`,
  `pos_start=0`, `pos_end=len(text)`. Lift it into a shared `cfront` helper:

```
def c_tok(c_node: object, orig_src: uni.Source, text: str = "") -> uni.Token {
    (line, col) = coord_of(c_node, 1);              # pycparser coord -> line/col
    tok = uni.Token(
        orig_src=orig_src, name="C_ANCHOR", value=text,
        line=line, end_line=line, col_start=col, col_end=col + max(len(text), 1),
        pos_start=0, pos_end=max(len(text), 1),
    );
    tok._is_synthetic = True;   # Token.init defaults this False (unitree.impl.jac:2196);
                                # this anchor has no backing source span, so mark it.
    return tok;
}

def emit_c_diag(c_node: object, num: int, anchor: uni.UniNode | None = None, **kw) -> None {
    # anchor = the real lifted uni node when one exists (it already has .loc from
    # its own kid tokens); else synthesize a locatable Token from the C coord.
    loc_node = anchor if anchor is not None else c_tok(c_node, self.orig_src);
    diag = DIAGNOSTICS[f"{'W' if self.lenient_c else 'E'}{num}"];  # E/W twin of one 42xx number
    self.cur_node = loc_node;
    self.emit(diag, node_override=loc_node, **kw);   # emit reads loc_node.loc only; returns bool
    # emit hands nothing back, so build the report record ourselves — same
    # format_message call emit makes internally — for the `# c2jac:` header + flags.
    self.c_diag_records.append(
        (diag.code, diag.format_message(**kw), loc_node.loc.first_line)
    );
}
```

When a real lifted node exists, pass it as `anchor` — it already has a genuine
`.loc` from its own kid tokens, so no synthesis and no `_stamp` fiction. Only
the pre-lift / dropped-construct case falls back to `c_tok`, and even that
builds a first-class synthetic `Token` tied to the C `Source`. `--lenient-c`
flips `self.lenient_c` once at pass construction.

| current | new |
|---|---|
| `_mark_tier_b` / `_mark_tier_b_idiom` call sites | `emit_c_diag(c_node, 42xx, anchor)` — the construct's number from the D.1 table |
| `_mark_tier_a` (faithful) | no emit (faithful path is silent) |
| `_surrogate` / `_surrogate_stmt` / `_surrogate_expr` (`UNSUPPORTED_*` sentinels) | build the named hole node (see below) + `emit_c_diag(c_node, 4290, anchor)` |
| `tags.jac` (`Tier`/`Mechanism`/`Idiom`/`TagTable`/`NodeTag`) | deleted; granularity carried by the distinct `E42xx`/`W42xx` codes |
| `boundary.jac` (`default_mechanism`) | deleted |
| `comments.jac` (`inject_tier_b_comments`, header) | `jac c2jac` renders the `# c2jac:` header + inline flags from the `emit_c_diag` records |

**Name the hole node — one shape, position-dispatched.** `_surrogate_expr`
today builds `Call(Name(UNSUPPORTED_EXPR), [line])` and `_surrogate_stmt` wraps
that in an `Expr`. The direct-lift equivalent is a single canonical hole so
implementers don't invent inconsistent placeholders:

- **Expression position** → `uni.FuncCall(target=uni.Name("__c_unsupported__"),
  params=[uni.Int(<c_line>)])` (`unitree.jac:1170`/`1519`). It unparses cleanly
  (readable in `jac c2jac` output) but resolves to an unbound name, so under
  strict ingestion the paired `E4290` (`blocks_codegen=True`) stops codegen — the
  hole never silently reaches a backend.
- **Statement position** → the same `FuncCall` wrapped in `uni.ExprStmt`
  (`unitree.jac:708`), mirroring the current `ast3.Expr` wrap.

Both route through `emit_c_diag(c_node, 4290, anchor)`; the surrogate node *is*
the `anchor`, so the diagnostic and the hole share one `.loc`.

## E. Files that move to `compiler/cfront/` (Phase 1)

**Truly intact (path rewrite only):** `preprocess.jac`, `c_types.jac`,
`c_idioms.jac`, `c_dataflow.jac` — pure C front-end, no `tags.jac`/pyast/splice
coupling.

**Move with a small refactor** (they import from `tags.jac`, which §C/§D
delete — so the import can't just be re-pathed):

| file | current `tags.jac` dependency | refactor |
|---|---|---|
| `c_common.jac` | imports `BinKind` (`c_common.jac:4`), used by `C_BINOPS` | move `BinKind` out of the doomed `tags.jac` into `cfront/c_common.jac` itself (or a tiny `cfront/c_kinds.jac`); `BinKind` is an operator-classification enum with no Tier/Idiom coupling, so it survives the tag-system deletion |
| `enum_prepass.jac` | imports `Idiom, Tier, Mechanism, NodeTag, TagTable` (`enum_prepass.jac:2`) | its verdicts (`ENUM_AS_ENUM`/`ENUM_AS_CONSTS`) currently ride the `Idiom` enum; replace with a local `cfront` enum (e.g. `EnumShape` with `NONE`/`ENUM_AS_ENUM`/`ENUM_AS_CONSTS`) independent of `Tier`/`Idiom`, since the enum-shape decision is a real lift choice that outlives the tag system |

**These `EnumShape` verdicts are shape selectors, not diagnostics.** `NONE`,
`ENUM_AS_ENUM`, and `ENUM_AS_CONSTS` pick *which* faithful uni node `proc_enum`
builds (§B) — none of them emit `E/W42xx`. Only an actual *unfaithful* enum
fallback (a shape the prepass can't lower at all) routes through `emit_c_diag`
with `4290`. Do not collapse the shape enum into the diagnostic set.

`bindgen.jac`'s extraction core (`FuncSig`, `StructDefs`, `ffi_prim`,
`--only`/`--never`) moves in Phase 3.

## F. Resolved node-construction notes (was "open questions")

Both prior open questions are settled against the live node defs in
`jac0core/unitree.jac`; no unknowns block Phase 1.

**`proc_for` → `uni.IterForStmt` — fully constructible, no splice.** The node
(`unitree.jac:759`) has exactly four slots, each already produced by an existing
`_for_*` helper:

| `IterForStmt` slot | type | fed by | shape |
|---|---|---|---|
| `iter` | `Assignment` | `_for_init_stmts` | `i = 0` (the single-valued init the promotable gate guarantees) |
| `condition` | `Expr` | `_for_lower_cond` | `i < n` (`<`/`<=`/`!=`, gate-guaranteed) |
| `count_by` | `Assignment` | `_for_step_stmts` | `i += 1` — **must be an `Assignment` with `aug_op` set** (C `i++`→`+=`, `i--`→`-=`), not a bare expr |
| `body` | `Sequence[CodeBlockStmt]` | `_stmts_from` | loop body |

`_for_promotable` already enforces precisely this shape (single-valued init,
relational cond, inc/dec-or-aug step), so the promotable branch is a direct
`uni.IterForStmt(...)` construction. The reference implementation is **not**
`CUniBuilder` (which builds only enums) — it is `splice._promote_for`
(`splice.jac:28`), and two build details there are load-bearing:

- **`iter` is rebuilt with `mutable=True`** (`splice.jac:80`). The desugar's init
  `Assignment` is not mutable; the loop variable must be, so `proc_for`
  reconstructs the `Assignment` (`kid=[tgt, val]`, `mutable=True`, `aug_op=None`)
  rather than reusing the init node verbatim.
- **the `condition` is unwrapped from `AtomUnit`** (`splice.jac:91`): if
  `_for_lower_cond` produced a parenthesized `uni.AtomUnit`, take `.value` before
  placing it in the `condition` slot.

`count_by` reuses the step `Assignment` (with `aug_op` populated for `i++`→`+=`).
Non-promotable `for` stays the `init; while` desugar (`uni.WhileStmt`).

**Pointer & cast classification — faithful / lossy-with-diagnostic /
unliftable.** This is the authority for invariant 4; §A `notes` defer here. The
current code (`expressions.impl.jac:97`, `:273`) does **not** treat all pointer
uses alike, and the plan must preserve that split:

| construct | class | lowering | current behavior |
|---|---|---|---|
| `&x`, `*x` on a **simple ref** | **faithful (silent)** | drop the operator, use `x` | Tier-A `PTR_REF`, no comment (`expressions.impl.jac:97-110`) |
| `&expr`, `*expr` on a **complex** operand | **unliftable** | surrogate / error node | `_surrogate_expr` today |
| `a->b` | **faithful (silent)** | `AtomTrailer(is_attr=True)`, deref vanishes | same node as `a.b` |
| pointer/identity `Cast` (`(T*)x`) | **faithful (silent)** | lowered operand unchanged, no node | passthrough |
| scalar `Cast` (`(int)x`, fixed-width) | **lossy-with-diagnostic** | **operand elided, value passes through** — do **not** synthesize `int(x)` | Tier-B: "representation-changing conversion not applied" (`expressions.impl.jac:273-282`) |
| `ExprList` in a for clause | **faithful** | flatten to statement sequence | `_for_init_stmts` |
| `ExprList` in expression position | **lossy-with-diagnostic** | lower to the last sub-expr | Tier-B: leading side effects dropped (`expressions.impl.jac:255-268`) |

Correction to an earlier draft: `(int)x` does **not** become `int(x)` — that
would silently *add* a truncation/narrowing the current transpiler deliberately
does not model. The faithful move is to elide and emit a width/sign/truncation
diagnostic (a dedicated code for fixed-width C integer targets so the user sees
exactly what was skipped). Likewise `->`/`&`/`*` are not a blanket
`pointer-elided` emit — simple refs stay silent, only complex operands escalate.

The takeaway: every §A/§B row maps to a *concrete, existing* uni constructor.
The residual C-vs-Jac gaps are **fidelity** concerns, each pinned to one of the
three classes above and routed through §D — not missing-node blockers.
