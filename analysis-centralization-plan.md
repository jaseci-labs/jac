# One Owner Per Analysis: Centralizing Jac Compiler Semantics on the UniTree

## Mission

Every semantic fact about a Jac program is computed **exactly once**, by the
centralized analysis pipeline, and recorded **on the unitree** (or in a
registry hanging off it). The three backend pathways - **sv** (Python
ast/bytecode), **cl** (ECMAScript), **na** (LLVM native) - become pure
*consumers*: they read annotations and emit target code; they never resolve,
infer, classify, scan, or re-derive.

Today the native backend carries a complete shadow compiler inside
`NaIRGenPass` (a stringly-typed shadow type system, shadow scoping, a shadow
class/layout model, its own closure analysis, its own OSP semantics, its own
ownership analysis), and the ES backend carries a smaller one (its own scope
stack, type-driven emission heuristics, OSP pre-scans, Ref-detection by AST
shape). This plan relocates each of those responsibilities into the central
system in **self-contained phases**: each phase moves one whole
responsibility, deletes the duplicate in the same change, and leaves exactly
one owner - **no fallbacks, no transition shims that outlive the phase**.

## Execution status (this branch)

Work executed so far on `docs/analysis-centralization-plan` (validated per
slice against the full native suite, 398 passed / 1 skipped):

- **Phase 1 (type authority) - largely done.** `TypeBase.mangle()` is the
  canonical type key; checked-type helper seams (`_type_key_of`,
  `_enum_name_of`, `_tuple_key_of`, `_set_spec_of`, `_dict_key_of`,
  `_list_spec_of`, `_struct_name_of`, `_elem_spec_of`) replace AST sniffing in
  native codegen. Deleted shadow dicts: `var_list_elem_type`, `var_dict_type`,
  `var_set_elem_type`, `var_tuple_type`, `var_enum_type`, `var_complex`,
  `var_range`, `var_slice`, `type_var_map`, `_last_type_node_hint`,
  `var_type_node`. Deliberately kept: `_list_type_hint` /
  `_dict_val_type_hint` (blocked: the checker does not bidirectionally type
  empty collection literals - `x: list[str] = []` leaves the ListVal typed as
  bare `list`), `var_list_elem_struct` (Phase 7 ownership), `field_type_node`
  (remaining readers are clib foreign-ABI lowerings, Phase 8).
- **Phase 2 (symbol/scope authority) - native consumers migrated** to
  `Symbol.storage`.
- **Phase 3 (layout) - partially done (pre-existing + this branch).**
  `LayoutPass`/`LayoutRegistry` own hierarchy, C3 MRO, topo order, vtable
  need, and primary-ancestor queries; native consumes them. Still native-local:
  LLVM field index/type maps (`struct_field_indices`/`struct_field_types`,
  prefix slots for vtable/`__type_tag`), vtable slot ordering. Migrating field
  flattening to `ArchetypeLayout.fields` needs care in mixed
  native/non-native hierarchies (native currently skips non-native ancestors'
  fields; the registry flattens all).
- **Phase 5 (OSP semantics) - in progress.** New unitree API:
  `Archetype.arch_kind` getter ("node"/"edge"/"walker", from `sym_category`) -
  all 1:1 kind checks across checker/static/semantic/boundary/layout/ES passes
  migrated. New `Ability.event_triggers` (list of checker-resolved trigger
  `TypeBase`s) populated by `TypeCheckPass._check_event_trigger_archetype`;
  native prefers it (mangled keys, `type[X]` unwrapped, unions split) for
  event-method location typing, E5091 union-layout validation, and OSP slot
  collection, with trigger-AST fallback when unresolved. Follow-up: ES
  `_osp_trigger_names` should consume `event_triggers` too (needs care:
  checker names like `Root` vs AST head names like `root`).
- **Phase 6 (construct semantics) - captures slice done.** New
  `UniScopeNode.get_enclosing_captures` + derived `LambdaExpr.captures`
  getter compute free variables centrally from symbol tables (a symbol is
  captured when its defining scope is a function-like scope strictly
  enclosing the scope at hand). Native lambda capture lowering and
  nested-ability closure rejection (E5090) consume it; the AST-walking
  `_find_free_vars` is deleted. Native keeps its `local_vars` filter
  (restricts captures to live allocas; excludes sibling nested functions).
  Remaining: `IterationInfo`, with-items, match patterns, f-string parts.
- **Phase 4 (call semantics) - classification slice done.** New
  `FuncCall.call_kind` ("method"/"instantiation"/"builtin"/"function"),
  stamped by `TypeCheckPass.exit_func_call` from
  `symbol_utils.classify_call` at resolution time (TypeInferencePass is a
  TypeCheckPass subclass, so every full codegen compile stamps it). Native
  and ES call dispatch consume the stored fact; only nodes synthesized
  after checking (desugared pipe-forward) classify on the spot. Remaining:
  full `CallInfo` (resolved signature + default-arg exprs) so native's
  `method_ast_sigs` AST-signature cache can be deleted.
- **Phase 0 (typed-tree consumption) - ES slice.** Three of four
  `get_type_evaluator()` sites in the ES backend (primitive-method
  dispatch, `_try_primitive_op`, `_expr_type_name`) now read `Expr.type`
  off the tree instead of re-querying the evaluator. The remaining site
  (`_resolve_call_ability`) is kept because the evaluator call repopulates
  a missing `.sym` as a side effect, not a pure type fetch.
- **Phase 10 (enforcement) - ratchet test landed early.**
  `tests/compiler/test_backend_purity.jac` statically scans
  `passes/ecmascript` + `passes/native` for analysis APIs
  (`type_evaluator`, `symbol_utils`, `type_tag.tag` reads, scope
  `.lookup(` calls) against a pinned allowlist of current violations that
  may only shrink (a staleness check forces ratcheting entries down as
  migrations land). The plan's "empty allowlist" end state is reached by
  draining it.

Remaining phases (7-9) are untouched; Phase 4 continues with `CallInfo`,
Phase 6 with `IterationInfo`.

## Architectural principles (the contract every phase enforces)

1. **Single owner.** For every analysis there is one pass/module that computes
   it. A second implementation - even a "cheap local check" - is a defect.
2. **No fallbacks.** When a backend needs a fact and the annotation is absent,
   that is an **ICE diagnostic** (internal contract violation), never a silent
   default (today: `_resolve_jac_type` silently falls back to `i64`,
   `types.impl.jac:230-242`). Fallback removal is part of each phase, not a
   follow-up.
   - *Scope note:* the self-hosting bootstrap re-entrancy guards in
     `jac0core/compiler.jac` (`_ir_sched_loading` etc.) are **not** analysis
     fallbacks - they exist so the compiler can compile itself. They stay, but
     each phase must keep bootstrap green.
3. **The unitree is the program.** Grow it wherever a semantic fact has an
   elegant home (`Expr.type` is the precedent; `Name.js_decl_kind` and
   `Module.gen.native_compat` are the proof that backend-facing annotations
   already live there). Surface fidelity is preserved: we **annotate**, we do
   not mutate surface syntax (the formatter/LSP constraint documented at
   `compiler.jac:95-99` stands).
4. **Analysis before codegen, always.** Codegen passes may not invoke the
   TypeEvaluator, walk `type_tag.tag` annotation ASTs, or do symbol-table
   lookups. They read node annotations and registries. (Phase 10 adds
   mechanical enforcement.)
5. **Tighten semantics where it simplifies.** Where backends currently
   diverge because each guesses, define the semantic once centrally (e.g.,
   typed-tree guarantee, one canonical type identity, declared ownership
   model) and hold all three backends to it.
6. **Representation growth is cached growth.** Any new unitree field must be
   added to the JIR registry (`jac0core/jir_registry.jac` via
   `gen_jir_registry.jac`) with a `FORMAT_VERSION` bump, or explicitly
   documented as recompute-on-load (like `Expr.type` today,
   `impl/jir_passes.impl.jac:834-839`). No accidental cache divergence.

## Current-state inventory (what is duplicated, where)

### The pipeline today (`jac0core/compiler.jac`, `impl/compiler.impl.jac:599-871`)

```
parse
└─ get_ir_gen_sched (compiler.jac:74):     ASTValidation → SymTabBuild → DeclImplMatch
                                           → SemanticAnalysis → SemDefMatch → CFGBuild
                                           → MTIRGen → UniTreeEnrich
└─ type check (CONDITIONAL, impl:702-746):
     jac check          → TypeCheck → StaticAnalysis → Portability → UniTreeEnrich(2nd!) → Lint
     native module      → TypeCheck only (get_native_inference_sched, compiler.jac:174)
     plain sv / cl      → NOTHING (Expr.type stays None)
└─ BoundaryAnalysis (always, compiler.jac:62)
└─ get_py_code_gen (compiler.jac:195):     EsastGen → NaIRGen → NativeCompile
                                           → PyastGen → PyJacAstLink → PyBytecodeGen
   LayoutPass: NOT scheduled - lazily invoked from backends
   (layout_pass.jac:75-88 get_layout_registry)
```

The root architectural defect: **type inference is conditional**, so backends
were built to survive without it - which is exactly why each grew a shadow
analyzer.

### Shadow systems in `NaIRGenPass` (`passes/native/na_ir_gen_pass.jac:103-924`)

| Shadow system | State / methods | Central system it duplicates |
|---|---|---|
| **Stringly-typed type system** | `var_list_elem_type`, `var_dict_type`, `var_set_elem_type`, `var_tuple_type`, `var_enum_type`, `var_complex/range/slice`, `var_type_node`, `field_type_node`, `var_list_elem_struct`, `_pending_list_elem_struct`, `_list_type_hint`, `_last_type_node_hint`, `type_var_map`; `_infer_type_name`, `_infer_list_elem_type`, `_peel_list_type`, `_get_list_elem_from_type_node`, `_infer_compr_elem_struct`, `_resolve_for_loop_elem_type`, `_infer_dict_type`, `_infer_global_init_type`, `_infer_unpack_struct_ptr`, `_extract_tuple_struct_hints`, `_extract_elem_struct_hint` | TypeEvaluator / `Expr.type` |
| **Shadow scoping** | `local_vars` (string-keyed), `param_vars`, `_declared_globals`, `_in_module_scope`, `_global_origins`, `func_symtab`, `method_ast_sigs` - reimplements Python scoping rules ("keeps na ⊆ sv", na_ir_gen_pass.jac:292-299) | Symbol / UniScopeNode tables |
| **Shadow class model** | `class_hierarchy`, `class_parents`, `mro_order`, `parent_field_start`, `arch_ast_map`, `has_vtable`, `vtable_layouts`, `vtable_method_indices`, `struct_field_indices`, `struct_field_types`, `struct_field_defaults`, `_union_layout_conflict` - reads LayoutRegistry for parents/MRO (objects.impl.jac:62-89) then **copies and recomputes the rest** | LayoutPass / LayoutRegistry |
| **Closure analysis** | `_find_free_vars` (na_ir_gen_pass.jac:347) | none - should be central |
| **OSP semantics** | `osp_arch_kind`, `_arch_kind`, `_osp_trigger_names`, `_is_walker_arch`, `_trigger_member_structs` | Symbol.sym_category + central trigger facts |
| **Ownership/RC analysis** | `_mark_owned`/`_is_owned` attributes on `ir.Value`, per-seam heuristics across `refcount.impl.jac`, `calls.impl.jac:750-800`, `stmt.impl.jac` | none - should be central (recurring owned-temp leak class) |
| **Foreign ABI analysis** | `_classify_clib_struct{,_sysv,_aapcs}`, `_clib_struct_layout`, `clib_struct_names`, `clib_fn_abi`, `_clib_type_name` (func.impl.jac:57-200, clib_abi.impl.jac) | none - should be a target library + type-system foreign types |
| **Capability gating** | `NATIVE_SUPPORTED_STDLIB` allowlist (na_ir_gen_pass.jac:29), E5090 unsupported-at-codegen | scattered: `UniTreeEnrichPass.native_compat`, PortabilityCheckPass |

### Shadow systems in `EsastGenPass` (`passes/ecmascript/impl/esast_gen_pass.impl.jac`)

| Shadow system | Where | Central system it duplicates |
|---|---|---|
| Scope stack for `let`-declaration decisions | `ScopeInfo`, `_push_scope`/`_register_declaration`/`_is_declared_in_any_scope` (:6693-6735) | Symbol tables + `js_decl_kind` |
| Type-driven emission heuristics (truthiness coercion, negative-index wrapping, collection detection) by AST shape | :2337-2461 | `Expr.type` |
| Lazy TypeEvaluator calls **during codegen** for primitive dispatch | `get_type_evaluator()` at :1738-1745 | pre-resolved call info |
| `Ref[T]` detection by walking annotation AST shape | `_ref_head_name` (:3820-3860, :3964-4010) | `Expr.type` (Ref is a type) |
| OSP pre-scans and var→archetype caches | `_osp_prescan`, `_osp_var_arch_cache`, `_osp_bases_cache` (:242-249, :4495-4602) | Symbol.sym_category + `Expr.type` |
| Import path re-resolution | :981-1020 | ModulePath resolution already done centrally (#6507 class of bugs) |

### What is already correct (the precedents to extend)

- `Expr.type: TypeBase` populated by TypeCheckPass; native `_lower_type`
  consumes it (types.impl.jac:234-239).
- `symbol_utils.jac` (`classify_call`, `resolve_expr_symbol`,
  `collect_field_names`, narrowing-key extraction) - shared analysis used by
  both backends (but invoked *at codegen time*; Phase 4 moves the invocation
  into analysis and stores the result).
- `LayoutRegistry` (layout_pass.jac:91-104) - declared as "all backends can
  query", half-adopted by native.
- `BoundaryAnalysisPass` - single producer of interop facts, runs
  unconditionally (compiler.jac:54-64). This is the model: one producer,
  scheduled in the front-end, consumed everywhere.
- `UniTreeEnrichPass` - proof that backend-facing annotations belong on the
  tree (`js_decl_kind`, `native_compat`), but it is a junk drawer and is
  dissolved by Phases 2 and 9.

---

## Endgame architecture

```
parse → ASTValidation → SymTabBuild → DeclImplMatch → SemanticAnalysis
      → SemDefMatch → CFGBuild → LayoutPass → TypeInference (unconditional)
      → CallResolution ─┐ (annotations: Expr.type, FuncCall.call_info,
      → ConstructSemantics │  IterationInfo, captures, triggers…)
      → OwnershipAnalysis  │
      → CapabilityCheck ───┘
      → BoundaryAnalysis → MTIRGen
      ── [diagnostic-only extras on `jac check`: StaticAnalysis, Lint] ──
      → backends (pure emitters):  EsastGen | NaIRGen→NativeCompile | PyastGen→Bytecode
```

One analysis pipeline. Three emitters. Zero analysis below the line.

---

# The Phases

Each phase is a complete, self-contained relocation: **(a)** the central
system gains the responsibility, **(b)** every duplicate implementation is
deleted in the same phase, **(c)** missing-annotation paths become ICEs, not
defaults, **(d)** the full validation gate passes.

---

## Phase 0 - The Typed-Tree Contract (pipeline keystone)

**Responsibility relocated:** *deciding whether type analysis happens* moves
from per-backend special-casing to the pipeline itself. Type **inference**
becomes an unconditional stage of every full compile; type **diagnostics**
remain `jac check`-gated.

**Today:**

- `Expr.type` is populated only for `jac check` or native-bearing modules
  (`impl/compiler.impl.jac:680-746`); plain sv/cl compiles have `type=None`
  everywhere - the root cause of every backend shadow analyzer.
- `get_native_inference_sched` (compiler.jac:174-188) exists solely because
  native needs types and the pipeline doesn't guarantee them.
- `UniTreeEnrichPass` runs twice (tail of ir_gen + inside type_check sched)
  and rerunning analysis "mutates AST state that NaIRGenPass depends on"
  (compiler.jac:167-170) - passes are not idempotent.

**The change:**

1. Split the type system's two jobs explicitly: an **inference schedule**
   (populate `Expr.type`, resolve symbols/signatures; diagnostics suppressed
   except ICEs) that runs in `get_ir_gen_sched` for every module regardless of
   context, and a **checking schedule** (`jac check`: full diagnostics +
   StaticAnalysis + Lint).
2. Delete `get_native_inference_sched` and the entire
   `is_native_mod / run_type_check / implicit_native` decision tree in
   `impl/compiler.impl.jac:680-746`. Native diagnostics discipline (#6049) is
   preserved because native modules still surface TYPE-category diagnostics
   from the inference run gated on `CodeContext.NATIVE` (see memory:
   native diagnostics must stay gated to native context).
3. Make every analysis pass idempotent-or-once: `UniTreeEnrichPass` runs
   exactly once; the check schedule no longer re-runs it.
4. Establish the contract diagnostic: a new ICE code (`E9xx`,
   `Category.ICE`) for "codegen read a missing semantic annotation". All
   later phases use it.
5. The #6262 concern (type-checker false positives on idiomatic client code)
   is moot by construction: inference populates types but only `jac check`
   emits the TYPE diagnostics for sv/cl.

**Deleted in this phase:** `get_native_inference_sched`; the
`run_type_check` conditional block; the second `UniTreeEnrichPass` run; the
`.na.jac`/NativeBlock sniffing loop in `compile` (impl/compiler.impl.jac:690-712).

**Tightened semantics:** after the front-end, `Expr.type` is non-None for
every expression in every module (worst case `AnyType`). This is now a
language-implementation invariant, not a mode.

**Cost note:** this makes inference run on compiles that skipped it. The JIR
cache is the mitigation lever (bytecode fast-path skips passes entirely;
when passes do run, they run once per cache miss). Benchmark
compile-time before/after on `jac/` self-compile; if unacceptable, the fix is
cache-level (serialize types - see Phase 10), never conditional analysis.

**Done when:** all of `jac check` over `jac/jaclang`, the full pytest suite
(`../.venv/bin/python3 -m pytest jac`), and the cross-backend equivalence
suites (`jac/jaclang/compiler/tests/xbackend_equiv.jac`,
`test_osp_equivalence.jac`, `test_prim_equivalence.jac`) pass with the
conditional blocks deleted; grep proves no caller of the deleted schedules.

---

## Phase 1 - One Type Authority: native's shadow type system dies

**Responsibility relocated:** all value/variable/container type identity in
the native backend → `Expr.type` (TypeBase) + a single canonical type-key
function owned by the type system.

**Today:** native tracks types as **strings** ("int", "MyStruct",
"list:int") in ~14 dicts/sets keyed by *variable name*, with its own
inference (`_infer_*` family) reconstructing types from LLVM values and AST
shapes - a complete second type checker with different (weaker) semantics.
`_resolve_jac_type` falls back to `i64` whenever the central type is missing
or unhandled (types.impl.jac:230-242).

**The change:**

1. Add to the type system the canonical identity native needs:
   `TypeBase.mangle() -> str` (stable, unique key: `"list[int]"`,
   `"MyStruct"`, `"dict[str,MyStruct]"`) in `type_system/types.jac`. This is
   the **only** string form of a type anywhere in the compiler; backends key
   emission caches by it.
2. NaIRGenPass derives every type fact from `Expr.type` /
   `Symbol` (declared type via `get_type_of_symbol`): element types of
   containers, tuple shapes, enum-ness, range/slice/complex-ness, global init
   types, for-loop element types, comprehension element types, unpack shapes.
3. `_resolve_jac_type` loses the `i64` fallback: missing/unloweable type ⇒
   the Phase-0 ICE (or the existing E5090 family when it is a genuine
   "type not supported natively" case - a *capability* diagnostic, distinct
   from a *missing fact*).
4. Where native genuinely needs LLVM-level type info (e.g. struct of a boxed
   value), it derives it from the TypeBase via `_lower_type` - never from
   spelunking `ir.Value`s or annotation ASTs.

**Deleted in this phase (all from `na_ir_gen_pass.jac` state +
`na_ir_gen_pass.impl/`):** `var_list_elem_type`, `var_dict_type`,
`var_set_elem_type`, `var_tuple_type`, `var_enum_type`, `var_complex`,
`var_range`, `var_slice`, `var_type_node`, `field_type_node`,
`var_list_elem_struct`, `_pending_list_elem_struct`, `_list_type_hint`,
`_last_type_node_hint`, `type_var_map`; methods `_infer_type_name`,
`_infer_list_elem_type`, `_peel_list_type`, `_get_list_elem_from_type_node`,
`_infer_compr_elem_struct`, `_resolve_for_loop_elem_type`,
`_infer_dict_type`, `_infer_global_init_type`, `_infer_unpack_struct_ptr`,
`_extract_tuple_struct_hints`, `_extract_elem_struct_hint`, and every
`type_tag.tag` walk outside genuinely-foreign clib paths (those die in
Phase 8).

**Tightened semantics:** a native value's type is its checked Jac type. Any
program the shadow inference accepted but the type checker types differently
now follows the checker (fix the program or fix the checker - one truth).

**Done when:** the native test suites
(`jac/tests/compiler/passes/native/`, `test_native_marshal.jac`) and
equivalence suites pass; `grep -rn "_infer_\|var_.*_type\|type_tag.tag" passes/native/`
returns only the allowed clib sites; the chess/raylib native examples still
build and run.

---

## Phase 2 - One Symbol & Scope Authority

**Responsibility relocated:** name binding, scope membership, and
declaration-kind decisions → the central symbol tables, with binding facts
recorded on the tree.

**Today:**

- Native re-implements Python scoping for globals (`_declared_globals`,
  `_in_module_scope`, `_global_origins`, na_ir_gen_pass.jac:292-299), keys
  locals by bare strings (`local_vars`, `param_vars`), and keeps its own
  function registry (`func_symtab`, `method_ast_sigs`).
- ES keeps a parallel scope stack purely to decide "does this assignment
  need `let`" (`ScopeInfo`, esast_gen_pass.impl.jac:6693-6735) even though
  `js_decl_kind` exists.
- `UniTreeEnrichPass.enter_name` computes `js_decl_kind` from AST-shape
  guesswork (unitree_enrich_pass.impl.jac:9-25).

**The change:**

1. Grow the central representation with binding facts the symbol system
   already knows but throws away: on `Symbol` - `storage: SymbolStorage`
   (LOCAL | PARAM | MODULE_GLOBAL | CAPTURED | CLASS_FIELD), and on `Name`
   (definition sites) - `binds_new_var: bool` (true at the first binding in
   its scope). Computed in SymTabBuild/SemanticAnalysis where insertion
   already happens - not in a new scan.
2. Backends key every per-variable structure by **Symbol identity** (the
   `Symbol` object / its uuid), not by name string. Shadowing and nested
   scopes become correct by construction.
3. `js_decl_kind` is replaced by the same facts (`binds_new_var` +
   `storage == PARAM`); the ES scope stack is deleted; the enrich-pass
   `enter_name` is deleted.
4. Native global-rebinding semantics ("na ⊆ sv") now *fall out* of
   `Symbol.storage` - delete the re-implementation.

**Deleted in this phase:** native `local_vars`-by-name keying (replaced, not
removed - the dict remains but keyed by symbol), `param_vars`,
`_declared_globals`, `_in_module_scope`, `_global_origins`; ES `ScopeInfo`
stack + `_register_declaration` + `_is_declared_in_any_scope` + hoisting
bookkeeping that the central facts subsume; `Name.js_decl_kind` field and its
enrich-pass writer; the ES re-resolution fallback
`sym_tab.lookup(...)` at codegen time (esast_gen_pass.impl.jac:1045-1077) -
if `sym` is None at codegen, that's the ICE.

**Tightened semantics:** every `Name` is bound at analysis time or is a
diagnosed error. Codegen never "looks up" anything.

**Done when:** equivalence + ecmascript golden tests pass byte-identical (or
with mechanically-explained diffs); `js_decl_kind` no longer exists in the
tree; JIR registry updated (field removal also bumps FORMAT_VERSION).

---## Phase 3 - One Layout Authority: complete the LayoutRegistry migration

**Responsibility relocated:** class hierarchy, MRO, field layout, vtable
layout, defaults, and layout validity → `LayoutPass`/`LayoutRegistry`,
finished and scheduled.

**Today:** LayoutRegistry exists and natively claims to serve all backends
(layout_pass.jac:1-9) but: `FieldInfo.type_tag` is a **string** and
`type_node` an annotation AST (layout_pass.jac:43-51); native reads
parents/MRO/has_vtable then maintains 12 parallel dicts and recomputes slot
indices and field types itself (objects.impl.jac, vtable.impl.jac); the pass
is invoked lazily from inside backends (`get_layout_registry`,
layout_pass.jac:75-88) rather than scheduled.

**The change:**

1. `FieldInfo` carries `type: TypeBase` (from Phase 1's authority) plus
   resolved default info; `MethodSlot` carries the resolved `FunctionType`.
   `ArchetypeLayout` gains `parent_field_start` (already exists), full vtable
   slot table, and union-layout-compatibility facts (subsuming native's
   `_union_layout_conflict`).
2. Schedule `LayoutPass` in `get_ir_gen_sched` after type inference
   (Phase 0 made that unconditional). Keep the lazy accessor **only** as the
   bootstrap-fallback entry point and make it assert-not-recompute in normal
   compiles.
3. NaIRGenPass consumes layouts exclusively: struct creation, field GEPs,
   vtable globals, inherited-method wrappers, parent-field offsets - all
   index lookups go through `LayoutRegistry`.
4. ES walker-field collection (`collect_field_names` call sites) reads the
   same registry.

**Deleted in this phase:** native `class_hierarchy`, `class_parents`,
`mro_order`, `parent_field_start`, `arch_ast_map`, `has_vtable`,
`vtable_layouts`, `vtable_method_indices`, `struct_field_indices`,
`struct_field_types`, `struct_field_defaults`, `_union_layout_conflict`,
`_build_vtable`'s analysis half (emission of vtable globals stays), and the
archetype-body re-walks in objects.impl.jac (~500 lines); `FieldInfo.type_tag`
string field.

**Tightened semantics:** one MRO, one field order, one vtable shape - shared
by all backends; cross-backend object layout disagreements become impossible.

**Done when:** native object/inheritance/vtable tests + OSP equivalence pass;
`grep -n "mro\|field_indices" passes/native/` hits only LayoutRegistry reads.

---

## Phase 4 - One Call Resolution Authority

**Responsibility relocated:** "what does this call invoke" - dispatch kind,
target, signature, receiver - resolved once during type checking and stored
on the tree.

**Today:** TypeCheckPass already resolves every call to validate it
(`validate_call_args`, `match_args_to_params`,
type_evaluator.jac:221-649) - then **throws the resolution away**. At codegen
time, ES and native each re-derive it: `classify_call` from `symbol_utils`
invoked per-callsite at emission (calls.impl.jac:37, esast_gen_pass.impl.jac:1833),
ES lazily instantiates the TypeEvaluator mid-codegen for receiver types
(:1738-1745), native re-walks signatures from `type_tag.tag`
(`_maybe_declare_ability`, func.impl.jac:30-41) and keeps `method_ast_sigs`.

**The change:**

1. Grow unitree: `FuncCall.call_info: CallInfo` written by TypeCheckPass at
   resolution time. `CallInfo` (new, in `type_system` or `unitree.jac`):
   `kind` (FUNCTION | METHOD | INSTANTIATION | BUILTIN_FN | PRIMITIVE_METHOD |
   MAGIC | CLIB | WALKER_SPAWN), `target: Symbol|None`,
   `signature: FunctionType|None`, `receiver_type: TypeBase|None`,
   `primitive_op: str|None` (canonical op id, e.g. `"list.append"`, for
   builtin/primitive dispatch shared by all backends).
2. Function/ability declaration in native reads `FunctionType` (param/return
   TypeBase) from the ability's symbol - `_maybe_declare_ability` stops
   walking annotation ASTs.
3. Both backends' dispatch switches read `call_info`; the per-backend
   *emission tables* (primitives_es / primitives_native / builtins.impl) keep
   their emitters but are **indexed by `primitive_op`**, so "which method is
   this" is decided once, centrally.
4. `symbol_utils.classify_call` becomes internal to the central resolver (or
   inlined into TypeCheckPass) - no codegen-time callers remain.

**Deleted in this phase:** `method_ast_sigs`; codegen-time `classify_call`
imports in both backends; ES's lazy `get_type_evaluator()` codegen calls and
`_resolve_primitive_type_name`; native's per-call builtin name-matching
heuristics; signature re-derivation in `_maybe_declare_ability` /
`_forward_declare_imported_ability`.

**Tightened semantics:** call dispatch is type-checker semantics in all
backends, identically - including user-shadowed builtins (`len` redefined)
and method-vs-field-call distinctions.

**Done when:** equivalence suites + `test_prim_equivalence.jac` pass; grep
shows zero `classify_call`/`get_type_evaluator` references under
`passes/ecmascript/` and `passes/native/`; JIR registry updated for
`call_info` (serialize or recompute decision recorded).

---

## Phase 5 - One Archetype/OSP Semantics Authority

**Responsibility relocated:** archetype kind, event-ability triggers, spawn
semantics, walker/node/edge facts → central analysis (aligned with the

# 6146 OSP-kernel decoupling: compiler-emitted ability triggers are already

the direction).

**Today:** native derives archetype kind by token inspection (`_arch_kind`),
trigger membership by AST walks (`_osp_trigger_names`,
`_trigger_member_structs`), walker-ness by name lookup (`_is_walker_arch`);
ES pre-scans the whole module for archetype kinds and event abilities
(`_osp_prescan`, :4495-4525) and caches var→archetype bindings by scanning
assignments (`_osp_var_arch`, :4578-4602) - facts that `Symbol.sym_category`
and `Expr.type` (post Phase 0/1) already determine.

**The change:**

1. Grow the tree where the fact belongs: `Archetype.arch_kind` getter is
   already derivable from `sym_category` - make it the single API;
   `Ability.event_triggers: list[TypeBase]` resolved+stored by TypeCheckPass
   (the same resolution that #6146's `@set_trigger` emission needs - one
   producer for both runtime and compile-time consumers).
2. Spawn expressions get resolved operand facts: which side is the walker
   (from `Expr.type`), recorded on the `BinaryExpr`/spawn node
   (e.g. `spawn_info`), replacing both backends' operand sniffing
   (`_spawn_operand_name`, ES kw-arg/walker checks E5080/W5014 move to the
   central checker as TYPE/SEMANTIC diagnostics).
3. ES and native consume: descriptor/table generation in native and
   `useEffect`/RPC-stub decisions in ES read the stored facts.

**Deleted in this phase:** native `_arch_kind`, `osp_arch_kind`,
`_osp_trigger_names`, `_is_walker_arch`, `_trigger_member_structs`; ES
`_osp_prescan`, `_osp_var_arch_cache`, `_osp_bases_cache` and the
assignment-scanning that fills them; the spawn diagnostics emitted from
codegen (E5010/W5013/W5014/E5080 relocate to central semantic analysis).

**Tightened semantics:** OSP trigger matching and spawn validity are defined
once; sv/cl/na agree on which abilities fire for which archetypes (the
equivalence suite asserts it).

**Done when:** `test_osp_equivalence.jac` passes across all three pathways;
OSP diagnostics fire from `jac check` without running codegen.

---

## Phase 6 - One Construct-Semantics Authority (desugaring facts)

**Responsibility relocated:** the *semantic decomposition* of compound
constructs - what to iterate, what is captured, what protocol methods are
involved - computed once and stored. (Syntactic emission stays per-backend:
PyastGen maps comprehensions to Python comprehensions natively; forcing a
shared lowering would pessimize it. The duplication worth killing is the
*analysis inside* each backend's lowering, not the lowering itself.)

**The change - grow unitree with resolved construct facts:**

1. `IterationInfo` on `InForStmt`/`InnerCompr`: the iterable's resolved
   protocol (LIST | STR | RANGE | DICT_KEYS | ITERATOR | …), element
   TypeBase(s), and for iterator-protocol cases the resolved
   `__next__`/`__iter__` members. Replaces native's
   `_resolve_for_loop_elem_type`/`_build_iter_from_expr` analysis half and
   ES's equivalent inspection.
2. `captures: list[Symbol]` on `LambdaExpr` (and nested `Ability`):
   central closure analysis using the symbol tables (a `Symbol` whose uses
   cross a scope boundary is the definition of captured - the symbol system
   already sees this). Replaces native `_find_free_vars`.
3. `WithStmt` items: resolved `__enter__`/`__exit__` ClassMembers.
4. `MatchStmt` patterns: resolved binding symbols + class-pattern layout
   references (LayoutRegistry from Phase 3).
5. F-string parts: each `FormattedValue` already has `Expr.type` (Phase 0);
   formatting decisions (which to-string path) derive from it - both
   backends delete their per-part type sniffing.

**Deleted in this phase:** native `_find_free_vars`, the analysis halves of
`_build_iter_from_expr`/`_try_iter_protocol_for`/comprehension element
resolution; ES comprehension/iteration type inspection; any remaining
`type_tag` walks in either backend for these constructs.

**Tightened semantics:** iteration and capture semantics are identical in
all backends; a construct that can't be decomposed is diagnosed centrally
(capability diagnostic), not discovered mid-emission.

**Done when:** comprehension/iterator/context-manager native tests +
equivalence suites pass; the only `InnerCompr` consumers in backends are
emitters reading `IterationInfo`.

---

## Phase 7 - One Ownership/Lifetime Authority

**Responsibility relocated:** ownership classification (OWNED | BORROWED |
STATIC) and release obligations → a new central `OwnershipAnalysisPass`
(CFG-aware), replacing native's per-seam heuristics.

**Today:** ownership is decided instruction-by-instruction inside emission
(`_mark_owned`/`_is_owned` attributes stuck onto `ir.Value`s;
calls.impl.jac:750-800; scope cleanup in stmt.impl.jac:226-290), and every
value-consumption seam (call args, `in`, `set.add`, for/compr iterables,
return tuples - `_return_tuple_ctx`) needs hand-written release logic. This
is the documented recurring leak class (owned-temp leaks; see memory
playbook) - precisely because the analysis has no single home.

**The change:**

1. New `OwnershipAnalysisPass` in `passes/main/` running after
   CallResolution (Phase 4) + ConstructSemantics (Phase 6): computes, per
   `Expr`, `ownership: Ownership` (OWNED/BORROWED/STATIC - function results
   and fresh allocations are OWNED, field/element loads BORROWED, literals
   STATIC), and per consumption seam the release set (which owned temps die
   here) and per scope-exit the live-local release list - using the CFG that
   already exists (`bb_in/bb_out`, cfg_build_pass) for early-exit paths
   (return/break/continue/raise).
2. The rules live in one place, derived from `call_info` (a call's result
   ownership is a property of its resolved signature - later this is where
   borrow/move FFI attributes from the FFI-ABI RFC plug in).
3. NaIRGenPass becomes mechanical: emit retain/release exactly where the
   annotations say. `_emit_scope_cleanup`/`_emit_loop_iter_cleanup` read the
   computed lists. The RC *mechanics* (helper functions, header layout,
   sentinel) stay native-only - they are emission, not analysis.
4. This pass is scheduled only when a native-context module is present (it
   is meaningless for GC backends today) - but it is **the** owner: when a
   future wasm/GC-RC backend appears it consumes the same annotations.

**Deleted in this phase:** `_mark_owned`/`_is_owned` and the `is_owned`
attribute convention on `ir.Value`; `_release_owned_operands`/
`_release_owned_args` decision logic (the emission helper remains, driven by
annotations); `_return_tuple_ctx`; `_param_store_instr`/`_param_promoted`
heuristics (borrowed-param promotion becomes an analysis fact); every
inline ownership comment-and-special-case across refcount/calls/stmt impls.

**Tightened semantics:** the ownership model is a written invariant
(documented in the pass docstring) instead of folklore distributed across
emission sites. The leak-diagnosis playbook becomes "read the annotation".

**Done when:** `test_native_gc.jac` passes; the chess-engine leak case study
(memory: native-rc-owned-temp-leaks) runs leak-free under
`JAC_RC_DEBUG_CODEGEN=1`; no ownership decisions greppable in emission files.

---

## Phase 8 - One Foreign-Boundary Authority (clib/FFI)

**Responsibility relocated:** foreign declarations, foreign struct layouts,
and psABI classification → the type system (foreign types as first-class
types) + a standalone target-ABI library. Direct continuation of the
validated FFI-ABI redesign RFC (#6353: root cause = no first-class foreign
boundary).

**Today:** clib externs/structs live as string sets and dicts inside
NaIRGenPass (`clib_struct_names`, `clib_fn_abi`, `clib_struct_abi_types`,
`_clib_type_name` walking annotation ASTs, func.impl.jac:57-200), and System
V/AAPCS classification is methods on the codegen pass
(`_classify_clib_struct{,_sysv,_aapcs}`, `_clib_struct_layout`).

**The change:**

1. The type system models foreign entities: a `ForeignType`/CType layout
   category in `type_system/types.jac` (size/align/fields with C layout), and
   clib `def` imports resolve to `FunctionType`s flagged foreign with their
   declared C types. TypeCheckPass/`CallInfo.kind == CLIB` flows from
   Phase 4.
2. psABI classification becomes a pure library
   `compiler/targets/abi.jac` (`classify(ForeignType, triple) -> AbiPlan`):
   no pass state, unit-testable against C-compiler-generated expectations
   (`test_native_marshal.jac` already exists as the harness).
3. The marshalling *plan* for each foreign call is computed during analysis
   (attached to `call_info` or a module-level foreign manifest); NaIRGenPass
   emits from the plan (`_codegen_clib_call` keeps the emission half:
   materialize/copy/box helpers).

**Deleted in this phase:** `clib_struct_names`/`clib_fn_abi`/
`clib_struct_abi_types` as pass state; `_clib_type_name` AST walking;
`_classify_clib_struct*`/`_clib_struct_layout`/`_scalar_layout` from the
pass (logic moves, pass methods die); `_resolve_clib_type`'s special-case
chain (foreign types lower through `_lower_type` like everything else).

**Tightened semantics:** the foreign boundary is declared, typed, and
checked - a foreign call that can't be marshalled is a `jac check`
diagnostic, not a codegen surprise. This is the seam the phased FFI RFC
builds on.

**Done when:** `test_native_marshal.jac` + raylib example pass on x86_64 and
aarch64 triples; ABI library has direct unit tests; codegen contains zero
classification logic.

---

## Phase 9 - One Capability/Portability Authority

**Responsibility relocated:** "can this construct compile on this pathway"
→ a single declarative capability model checked before codegen.

**Today, three disconnected systems:** `UniTreeEnrichPass`'s syntactic
`native_compat` scan (unitree_enrich_pass.impl.jac:28-100);
`NATIVE_SUPPORTED_STDLIB` allowlist + E5090/E5060 "unsupported" errors
emitted **during** native emission (na_ir_gen_pass.jac:17-29,
expr.impl.jac:131, core.impl.jac:939); and `PortabilityCheckPass` for JS-isms
(W6001-6004). The ES pass also discovers unsupported shapes mid-emission
(E5011 fallbacks).

**The change:**

1. New `CapabilityCheckPass` in `passes/main/` (absorbing
   PortabilityCheckPass): a declarative table of (construct/feature ×
   pathway) support, evaluated over the analyzed tree. Produces (a)
   pre-codegen diagnostics for context-mandated targets (a `na {}` block
   using an unsupported feature errors here, with the E5090-family codes,
   gated on `CodeContext.NATIVE` exactly as today's discipline requires) and
   (b) `Module.gen.native_compat` for the auto-promotion machinery - now
   derived from the same table instead of a parallel hand-maintained scan.
2. The stdlib allowlist moves into the table (per-module, per-member
   support, the #6404 roadmap extension point) - codegen consults nothing;
   by the time emission runs, unsupported constructs were already diagnosed.
3. `UniTreeEnrichPass` is deleted (its last tenant after Phase 2 was
   `native_compat`).

**Deleted in this phase:** `UniTreeEnrichPass` (file + scheduling);
`PortabilityCheckPass` as a separate pass (folded in);
`NATIVE_SUPPORTED_STDLIB` from the codegen pass; mid-emission E5090/E5060
sites (the codes survive, raised from the capability pass; emission keeps
only true ICE guards).

**Tightened semantics:** "supported on native/client" is a spec (one table,
documentable, testable), not emergent behavior of which emitter methods
exist.

**Done when:** `test_native_feature_guardrail.jac` passes with diagnostics
now produced pre-codegen; auto-promote behavior unchanged on the test corpus;
enrich pass nonexistent.

---

## Phase 10 - Backend Purity: enforcement + cached semantics (endgame)

**Responsibility relocated:** the *architecture itself* gets an owner -
mechanical enforcement that analysis stays central, plus the cache learns to
carry semantics so analysis cost is paid once per change, not per build.

**The change:**

1. **Enforcement test** (in `jac/jaclang/compiler/tests/`): static scan of
   `passes/ecmascript/`, `passes/native/`, and the py-codegen passes
   asserting no imports/calls of `type_evaluator`, `symbol_utils` resolvers,
   `get_layout_registry`-with-compute, no `type_tag.tag` reads, no
   `.lookup(` on scope tables. The allowlist is empty; new violations fail CI.
   This is the "no second analyzer ever grows back" guarantee.
2. **Pipeline simplification:** with all phases landed, collapse the
   schedule builders in `jac0core/compiler.jac` to: one front-end analysis
   schedule (+ bootstrap fallback), one check-extras schedule, three emitter
   schedules. Delete the dead conditional structure.
3. **JIR carries semantics (decision gate):** evaluate serializing the new
   annotation set (`Expr.type` via a TypeBase pickle/intern section,
   `call_info`, `IterationInfo`, ownership, layouts) as new JIR TLV sections
   so cache hits skip the analysis pipeline entirely. This is a measured
   decision: implement if Phase 0's benchmark showed analysis dominating
   warm-cache compiles. Either outcome is recorded here with numbers.
4. **Docs:** promote the contract (principles section above) into
   `docs/internals/` as the compiler architecture spec; the
   framework-backend seam doc (`_planning/framework-backend-seam.md`)
   layers cleanly on top (its `EsastGenPass` is by now a pure consumer,
   which is exactly the precondition that plan's "intent records" need).

**Done when:** enforcement test green in CI; schedule code measurably
smaller; full suite + self-compile + equivalence matrix green.

---

## Cross-cutting rules (apply to every phase)

- **Validation gate per phase** (run with `../.venv/bin/python3` from `jac/`):
  1. `jac check` clean on `jac/jaclang` (self-hosting type discipline);
  2. full `pytest` suite for `jac/`;
  3. cross-backend equivalence: `compiler/tests/xbackend_equiv.jac`,
     `test_osp_equivalence.jac`, `test_prim_equivalence.jac`,
     `test_shared_types_equivalence.jac`;
  4. native suite `jac/tests/compiler/passes/native/` + examples
     (chess, raylib) build & run;
  5. ecmascript golden tests byte-stable unless the diff is mechanically
     explained in the phase's PR;
  6. bootstrap: clean-cache self-compile of the compiler
     (`rm -rf ~/.cache/jac/jir` first) - the re-entrancy guards must still
     converge.
- **Deletion is the acceptance test.** A phase isn't done while the old
  implementation exists behind a flag. Greps listed per phase are part of
  review.
- **JIR discipline.** Any unitree field add/remove ⇒ regenerate
  `jir_registry.jac` (`gen_jir_registry.jac`), bump `FORMAT_VERSION`, state
  serialize-vs-recompute in the phase PR.
- **Diagnostics keep their categories.** Relocated diagnostics keep codes
  where users may depend on them; new contract violations use ICE category.
  Native-context-only diagnostics stay gated on `CodeContext.NATIVE`
  (NaIRGenPass runs in every full compile - leaking its diagnostics into
  plain `.jac` builds is a known failure mode).
- **One phase, one PR train.** A phase may land as several commits but its
  branch merges only when its full gate passes - no half-relocated states on
  `main`.

## Dependency graph & suggested order

```
Phase 0 (typed-tree contract)
 ├─→ Phase 1 (type authority in native)
 │     ├─→ Phase 3 (layout: needs TypeBase field types)
 │     └─→ Phase 4 (call resolution: needs receiver/sig types)
 │           ├─→ Phase 5 (OSP: spawn/trigger facts use types+calls)
 │           ├─→ Phase 6 (construct semantics: iteration uses call/type facts)
 │           │     └─→ Phase 7 (ownership: consumes calls + iteration seams)
 │           └─→ Phase 8 (foreign boundary: CLIB call kind + foreign types)
 ├─→ Phase 2 (symbol/scope authority - independent of 1; do early, it's small)
 └─→ Phase 9 (capabilities - anytime after 0; before 10)
                Phase 10 (enforcement endgame - last)
```

Recommended execution order: **0 → 2 → 1 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10.**
0 and 2 are the cheapest and unlock the contract; 1/3/4 remove the bulk of
the native shadow compiler; 5–8 finish the deep semantics; 9–10 seal the
architecture.

## What stays per-backend (explicitly out of scope)

- Target IR construction and emission: ESTree building/printing, LLVM
  instruction emission, Python `ast3` construction, bytecode generation.
- Runtime libraries: `jac_runtime_js`, native RC runtime helpers/linkers
  (ELF/Mach-O/PE/WASM), `primitives_*` emitter bodies (now indexed by central
  `primitive_op`).
- Backend-idiomatic lowering choices (comprehension → `.filter().map()` vs
  LLVM loops vs Python comprehensions) - *given* the centrally computed
  semantic facts.
- The React/framework seam (separate plan:
  `_planning/framework-backend-seam.md`).
