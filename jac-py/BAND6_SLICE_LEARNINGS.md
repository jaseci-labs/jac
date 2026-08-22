# Band 6 slice learnings (JacPython native compiler)

**Read this before touching Band 7 generator/async work.** Band 6 landed in six commits
(`2094513ce` through `21111b1ab`; logical slices below). Do not re-derive facts already
captured here - verify against oracle fixtures and extend the patterns below.

Last updated: 2026-08-22 (`jac-python`, Band 6 slice 8 except-as in combined try/except/finally).

---

## 1. Two-axis maturity (still applies)

| Axis | Status on Band 6 HEAD |
|------|------------------------|
| **VM/runtime** | Broad: exception tables, `with`, `assert`, generator suspension already work when fed **host-compiled** PyCode |
| **Native compiler** | Band 6 closed for core try/except, raise, with, assert; deferred cases listed in §3 |

A slice is "done" when **native source → native compile → JacPython VM** matches CPython
oracle on the slice fixture (`co_code`, `exceptiontable`, `stacksize`).

---

## 2. Global invariants (Band 6 + carry-forward)

### 2.1 Pipeline and test pattern

Same as Band 4/5 §2.1. Each slice adds **paired** tests in:

1. `jac-py/jacpython/compiler_slice.jac` - `compile_parsed_exec`
2. `jac-py/jacpython/layer9_product_exec.jac` - `product_exec`

For Band 6+, always assert `exceptiontable` when non-empty (not just `co_code`).

Helpers: `nested_code_by_name`, `oracle_exec`, `assert_matches_oracle`, `compile_parsed_exec`.

### 2.2 Files by concern

| Concern | Primary files |
|---------|----------------|
| Exception lowering | `compiler_codegen.jac` (`visit_try`, `visit_try_finally`, `visit_raise_stmt`, `emit_except_as_cleanup`) |
| With / assert | `compiler_codegen.jac` (`visit_with`, `visit_assert_stmt`) |
| Exception regions | `compiler_ir.jac` (`except_region`), `assembler.jac` (`assemble_exception_table`) |
| Symtable (except bodies) | `compiler_symtable.jac` (`sym_visit_stmt` Try branch, `as` binding as `DEF_LOCAL`) |
| VM opcode registry | `jac-py/tools/vm_opcode_fixtures.py`, `layer_vm_conformance.jac` |

### 2.3 CPython 3.14 exception-table model (critical)

`except_region` fields consumed by `assemble_exception_table`:

| Field | Meaning |
|-------|---------|
| `start_block` | First protected block id (after `NOP` at try/with entry) |
| `end_block` | Block id **after** protected range (exclusive end marker) |
| `handler_block` | Handler entry block |
| `stack_depth` | 1 for try body; 2 for handler cleanup / `with` |
| `preserve_lasti` | True for handler-body unwind regions |

**try/except typed handler** (`visit_try`):

```text
  NOP                         # protect_start = cur.id
  <try body>
  <fallthrough / module return>
  --- handler_entry ---
  PUSH_EXC_INFO
  <load exc type>
  CHECK_EXC_MATCH
  POP_JUMP_IF_FALSE -> next handler or RERAISE
  [POP_TOP | STORE_FAST as binding]
  <handler body>
  POP_EXCEPT
  [except-as cleanup: LOAD_CONST None; STORE; DELETE_FAST]
  RETURN_VALUE
  --- no-match chain ends in RERAISE 0 ---
  --- unwind ---
  COPY 3; POP_EXCEPT; RERAISE 1
```

`stack_depth=1` on the try-body region; handler regions use `stack_depth=2` with
`preserve_lasti=True`.

### 2.4 try/finally without except (`visit_try_finally`)

Separate path when `handlers` empty and `finalbody` non-empty:

- Protected body + normal finally on success path
- `finally_except` handler: `PUSH_EXC_INFO`, run `finalbody`, `RERAISE 0`
- Nested regions: protect (depth 1) + finally-except unwind (depth 2, `preserve_lasti`)

**Not implemented:** `try/except/finally` combined (`NotImplementedError`).

### 2.5 except ... as e (`emit_except_as_cleanup`)

On handler exit (success or unwind):

```text
  LOAD_CONST None
  STORE_FAST e        # clear binding before delete
  DELETE_FAST e
```

Requires `emit_name_delete` (`OP_DELETE_FAST` for fast locals). Cell/free delete →
`NotImplementedError`.

Extra `except_region` entries wrap the handler body when `as` binding is present
(unwind on failure inside handler).

### 2.6 raise (`visit_raise_stmt`)

| Form | Lowering |
|------|----------|
| `raise exc` | evaluate `exc`; `RAISE_VARARGS 1` |
| bare `raise` | `RAISE_VARARGS 0` |
| `raise ... from cause` | `NotImplementedError` |

### 2.7 with (`visit_with`)

Single item, **`as` binding required** (no bare `with expr:`).

```text
  <context_expr>
  COPY 1
  LOAD_SPECIAL 1          # __enter__
  SWAP 2; SWAP 3
  LOAD_SPECIAL 0          # __exit__
  CALL 0                  # enter
  STORE_FAST x
  <body>                  # protect_start
  LOAD_CONST None x3
  CALL 3                  # __exit__(None, None, None)
  POP_TOP
  --- with_except handler ---
  PUSH_EXC_INFO
  WITH_EXCEPT_START
  TO_BOOL
  POP_JUMP_IF_TRUE -> suppressed
  RERAISE 2
  suppressed: POP_TOP; POP_EXCEPT; POP_TOP x3; RETURN_VALUE
  --- unwind: COPY 3; POP_EXCEPT; RERAISE 1 ---
```

`stack_depth=2` on protect region. Multiple `with` items → `NotImplementedError`.

### 2.8 assert (`visit_assert_stmt`)

```text
  <test in bool context>
  POP_JUMP_IF_TRUE -> ok
  LOAD_COMMON_CONSTANT 0   # AssertionError
  [optional msg: evaluate; CALL 0]
  RAISE_VARARGS 1
  ok:
```

### 2.9 visit_stmt tail / termination integration

`visit_try`, `visit_with`, and `visit_try_finally` accept `tail` / `tail_idx` /
`more_code_follows` so nested control flow can fall through correctly. Handler bodies
that do not terminate must emit `POP_EXCEPT` (+ except-as cleanup) then
`emit_module_return` - not fall through to the next handler block.

### 2.10 Symtable notes

- `Try` handlers: visit handler type expr and body stmts
- `except ... as name`: register `name` as `DEF_LOCAL` in the handler block
- `With` items: visit `context_expr` and `optional_vars` target

### 2.11 VM opcode fixtures added (Band 6)

### 2.12 Multi-handler try/except/finally (slice 7) - span model

`visit_try_except_finally` lowers `try/except+/else/finally` by forward-nesting
the finally around the try/except chain. Spans are collected in a local list and
coalesced by `merge_except_spans` **in layout position, not block id**
(`pos_of` from `g.u.blocks`) - deferred blocks are placed at first `use()`, so
id order != layout order. Overlapping spans with identical handler/depth/lasti
fold into the covering range.

Key CPython-congruent behaviors (each cost a debugging round; do not re-derive):

| Behavior | Rule |
|----------|------|
| Dead `else` after terminated body | CPython still registers its names/consts first (compile body -> orelse -> handlers), then strips the code. We emit into throwaway blocks (snapshot len of blocks/regions/pending + nested_* fields) and truncate after; `u.add_name` registers at emit time |
| Nested try/except as the whole outer try body | Inner publishes `nested_try_except_end` (its unwind block); outer body span starts there so entries never overlap. `body_is_try_except_only` gates it (finally-only variant pre-existed) |
| Bare last handler + late inline finally | handler-epilogue span ends at `fin_inline` (leading NOP), merging with the inner-unwind span; typed last ends at `reraise_blk` |
| Nested try in a handler body | Enclosing advertises `handler_fallthrough_fin/backward/fin_handler` + `handler_enclosing_unwind`; the nested try emits the enclosing epilogue inline per path (POP_EXCEPT + jump fin) instead of `emit_module_return`, gated on `not try_follows` (last statement only) |
| Region depths inside a handler body | `handler_nest_depth` (+1 per active handler frame) is added to the nested try's own regions (body 1+n, match/unwind 3+n); the split spans (first POP -> enclosing unwind dl3, inline epi -> fin dl1) take no adjustment |
| Nested handler span split | match+handler BODY are protected by the nested try's own unwind (up to the first POP_EXCEPT block); first POP maps to the enclosing unwind; epilogue to the fin handler; last-handler epilogue span ends at `reraise_blk` (not the empty block after) |

### 2.13 Bound handlers in visit_try_except_finally (slice 8)

Each `except E as e` handler gets its own deferred **as-cleanup unwind** block
(`emit_except_as_cleanup` + `RERAISE 1`), placed immediately after its epilogue.
CPython emits one per bound handler unconditionally - even when the body
terminates (explicit raise/return).

| Behavior | Rule |
|----------|------|
| Binding store placement | bound: STORE goes at the end of the MATCH block (before `use(body_blks)`), so body spans start after it; unbound: POP_TOP stays at the top of the body block (CPython's L5/L6 NOT_TAKEN / POP_TOP pair) |
| Span split | match portion -> inner unwind; body portion -> as-cleanup block; the as-cleanup block itself -> inner unwind via `au_end` (next/reraise/inner), coalescing with the reraise span |
| Terminated bound bodies | split entry->body->inner and body->as_unwind->as_unwind, plus the au span |
| Inline epilogues | nested tries falling through clear an enclosing binding via `handler_fallthrough_bind` (cfg field) after POP_EXCEPT |
| inner-unwind -> fin span | registered UNCONDITIONALLY (CPython keeps it even when no path reaches an inline finally copy); only `emit_finally_inline_block` is gated on `any_reaches_fin` |

Known remaining deferrals: bare
last handler with early inline finally layout (untested combination), statements
after a module-level terminator (pre-existing len-0 co_code bug - see §4).
Also pre-existing: `compile_parsed_exec`-style tests assert co_code/
exceptiontable/stacksize but NOT linetable; linetable parity is known-broken on
several already-committed band6 fixtures (flat except-as included).

Registered in `EMISSION_OPCODES` + `# vm-opcode:` fixtures:

`PUSH_EXC_INFO`, `CHECK_EXC_MATCH`, `POP_EXCEPT`, `RAISE_VARARGS`, `DELETE_FAST`,
`LOAD_SPECIAL`, `WITH_EXCEPT_START`, `LOAD_COMMON_CONSTANT`

(Also reuses Band 4/5 opcodes: `COPY`, `RERAISE`, `POP_JUMP_IF_*`, `CALL`, etc.)

---

## 3. Band 6 commit map

| Slice | Commit | Topic |
|-------|--------|-------|
| 1 | `2094513ce` | try/except typed handler |
| 2 | `fd9c3690c` | raise |
| 3 | `e83165e1e` | except ... as |
| 4 | `bd846d67d` | try/finally |
| 5 | `f42db58ef` | with |
| 6 | `21111b1ab` | assert |
| 7 | (this commit) | multi-handler try/except/finally (typed + bare chain, else, nested try in body/handler) |

---

## 4. Band 6 deferrals (not blockers for Band 7)

| Feature | Status |
|---------|--------|
| ~~bare `except`~~ | landed (slice 7, bare-last handler) |
| ~~`try/else`~~ | landed (slice 7) |
| ~~`try/except/finally` combined~~ | landed (slice 7; single-handler form earlier) |
| ~~`except ... as` in the combined finally path~~ | landed (slice 8) |
| `try` without except/finally | `NotImplementedError` |
| `raise ... from cause` | `NotImplementedError` |
| `with` without `as` | `NotImplementedError` |
| multiple `with` items | `NotImplementedError` |
| delete cell/free in except-as cleanup | `NotImplementedError` |
| statements after a module-level terminator | pre-existing bug: co_code becomes EMPTY (len 0) - names register, all blocks dropped. Repro: `raise ValueError('x')\nresult = 2\n`. Fix on a separate branch (touches module epilogue + dead-block stripping), not part of any Band 6 slice |

---

## 5. Band 7 next

Generators, coroutines, and async syntax - **not started** in native codegen.

`visit_stmt` returns `NotImplementedError` for `Yield` / `YieldFrom` stmt forms;
`AsyncFunctionDef` is not wired in `visit_stmt` (only `FunctionDef`).

Existing infrastructure to reuse:

- Symtable: `sym_block.generator`, `sym_block.coroutine` flags already set
  (`sym_visit_stmt` / `sym_visit_load_expr` for Yield, YieldFrom, AsyncFunctionDef)
- VM: generator suspension fixture in `layer_vm_conformance.jac` (host-compiled);
  `OP_YIELD_VALUE`, `OP_GET_YIELD_FROM_ITER`, `OP_SEND`, `OP_GET_AWAITABLE` in VM
- `function_code_flags` in codegen sets `CO_OPTIMIZED | CO_NEWLOCALS` only - must
  add `CO_GENERATOR` / `CO_COROUTINE` from symtable child flags in `compile_function_cfg`

Band 7 scope (separate slices/commits):

1. `def g(): yield value` - `YIELD_VALUE`, `CO_GENERATOR`, generator epilogue
2. `yield from` - `GET_YIELD_FROM_ITER`, `SEND` / `END_SEND`
3. `async def` - `CO_COROUTINE`, `visit_async_function_def`
4. `await expr` - `GET_AWAITABLE`, async function body lowering

Each slice: oracle `co_code` (+ `flags`), VM execution, VM opcode fixtures for new emissions.

---

## 6. Commit / PR discipline

| Rule | Detail |
|------|--------|
| One slice per commit | Message: `feat(jac-py): band-7 <slice name>` |
| Release note | `release_notes/unreleased/jaclang/<PR#>.feature.md` when opening PR |
| Local gates | `compiler_slice`, `layer9`, `layer_vm_conformance`, `grammar2jac --check`, `vm_opcode_fixtures.py --check` |

---

## 7. Common failure modes (symptom → look here first)

| Symptom | First check |
|---------|-------------|
| `exceptiontable` mismatch, `co_code` matches | §2.3 region `stack_depth` / `preserve_lasti` |
| Handler falls into next handler | §2.9 termination: `POP_EXCEPT` before return |
| except-as leaks binding | §2.5 cleanup on all exit paths |
| with body exception wrong stack | §2.7 `stack_depth=2`, `WITH_EXCEPT_START` chain |
| assert wrong exception type | §2.8 `LOAD_COMMON_CONSTANT 0` |
| try/finally reraise loop | §2.4 nested regions on `finally_except` |
| VM passes but native compile fails | Add `compile_parsed_exec` test, not just `product_exec` |

---

## 8. Quick reference - key functions

```text
compiler_codegen.jac
  visit_try                 # try/except typed handlers
  visit_try_finally         # try/finally only
  visit_raise_stmt          # raise exc / bare raise
  visit_with                # single with ... as
  visit_assert_stmt         # assert test [, msg]
  emit_except_as_cleanup    # None store + DELETE_FAST
  emit_name_delete          # DELETE_FAST (fast locals only)

compiler_symtable.jac
  sym_visit_stmt (Try)      # handler types + bodies + as binding
  sym_visit_stmt (With)     # context_expr + optional_vars

compiler_ir.jac / assembler.jac
  except_region             # start/end/handler blocks + stack_depth
  assemble_exception_table  # varint encoding for co_exceptiontable
```
