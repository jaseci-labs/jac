# Compact Codegen IR (JCIR)

Status: shipped. This format is the compiler's only Python codegen. The
emitter (`compiler/backends/py/jcir_gen_pass.jac`) produces it from the
annotated unitree for the whole language, the shim seat
(`compiler/backends/py/jcir_bc_gen_pass.jac`) turns the bytes back into
CPython code objects. The Python-AST emitter it was measured against
(`pyast_gen_pass`), its bytecode pass, and the `JAC_CODEGEN` flag that
chose between them were deleted at the cutover, which is where the
two-codegen era ends. Sections 1 through 8 are the design record and
describe the old emitter in the present tense as it stood when they were
written; sections 9 onward describe the tree as it is.

This was the first lane 2 deliverable of the zero-bytecode endgame,
epic #8201: it fixes the Step 4 shim's contract and is the proof that
the intermediate annotated-state materializer is skippable at all. What
remains ahead of it is the mega-arc's own work -- per-node dispatch, and
retiring the Python shim seat for a generated native transcriber, which
must conform to the bytes specified here.

Status note (#8732): the native seal, the fused `libjac_compiler` build,
the pass-serving binder, and the `mat_parse` materializer crossing that
this document refers to were removed. The compiler modules served natively
are now listed in `compiler/native_scope.jac`, empty until a native pass
can share the tree with a bytecode pass. The sealed-lane paragraphs below
(sections 2, 9 and 11) are the record of what was measured before the
removal and the precedent the next crossing builds on; the tests and
waiver tables they name no longer exist.

Note on location: the task brief suggested `docs/community/internals/`; the
corpus's actual home for internal design docs is `docs/internals/` (beside
`compiler_architecture.md`, `interop.md`, `ownership-checker-spec.md`), so
this document lives there.

## 1. What problem this format solves

Today codegen is two passes at the end of the pipeline:

- `compiler/passes/pyast_gen_pass.jac` (+impl, about 4,500 lines, 169
  methods; measured 2026-08-14: 137 of 169 methods are `ast3`-bound) walks the
  annotated unitree and builds a CPython `ast` tree per module.
- `compiler/passes/pybc_gen_pass.jac` (3 methods) calls `compile()` on each
  `ast.Module` and `marshal.dumps` the code object.

`pyast_gen` interleaves two very different kinds of work:

- **Decisions**: which ast shape each unitree node lowers to, symbol
  mangling (`_py_name`, `KW_INIT` to `__init__`), scope handling (self/cls
  injection, global/nonlocal directives), temporaries (`__jac_temp_N`,
  `_jac_lambda_N`), lambda hoisting and frame placement, preamble assembly
  (jaclib/builtin/typing import dedup), switch lowering to a while/if
  chain, jsx lowering via `PyJsxProcessor`, semstr decorators, docstring
  placement, `TYPE_CHECKING` wrapping, the `TOKEN_AST_MAP` operator table
  (45 token kinds to ast classes), and every emitted diagnostic.
- **Construction**: actually instantiating `ast3.*` objects, stamping
  lineno/col via `sync()`, and handing the tree to `compile()`.

In the sealed pipeline the decisions run natively, but construction is
CPython's business by definition. The compact codegen IR is the boundary
between them: **decisions happen in the sealed pipeline and are encoded;
the shim only transcribes.** Every instruction has exactly one
transcription. The shim makes no choices, so it can stay small, dumb, and
version-tracking, exactly as the Step 4 shim principle from #8139 demands:
the shim tracks CPython internals (builds `ast` objects and calls
`compile()`) rather than owning `co_linetable`. CPython owns line tables.

The production crossing then collapses to: IR bytes in, code objects plus
diagnostics out. Full annotated trees never cross in production.

## 2. The crossing, by analogy to the parser materializer

The proven pattern is the `mat_parse` crossing
(`compiler/frontend/parser/materialize.jac` on the Python side,
`compiler/native_materialize.jac` generated at seal time by
`dist/gen_native_materialize.jac` on the native side):

- one GIL-held `PYFUNCTYPE` entry per crossing, returning a fully
  Python-owned result;
- handle tables registered at bind time (`mat_reset`, `mat_set_class`,
  `mat_set_key`, `mat_set_enum`) so the native side can construct Python
  objects by index, never by name lookup at runtime;
- string transport through `jac_str_new`;
- `Py_DecRef` ownership discipline on the returned handle;
- a per-crossing memo flush (`_mat_flush`) for the identity-preserving
  object graph.

JCIR points this machinery at `ast` construction instead of unitree
construction, with two deliberate simplifications:

1. **No memo table.** The materializer needs `_mat_memo` because unitree
   is a mutation-aliased object graph where identity matters (decl-impl
   matching deliberately leaves two scopes sharing one dict). An ast tree
   handed to `compile()` has no identity semantics: where `pyast_gen`
   reuses one ast object in two places (for example `executed_assign` in
   `resolve_switch_stmt`), duplicating the construction is
   semantics-preserving. JCIR is therefore strictly a tree, shared
   subtrees are emitted twice, and the whole aliasing apparatus that makes
   the annotated-state materializer hard is simply absent. This is the
   concrete sense in which the intermediate materializer of #8139 Step 3
   is skippable.
2. **The construction recipe crosses as data.** The native side does not
   hardcode ast shapes; it emits a byte stream. The transcriber that walks
   the stream and constructs `ast.*` objects exists twice, by design:
   - the **Python reference shim** (`compiler/backends/py/codegen_shim.jac`, this
     change): consumes IR bytes with plain `import ast`, used by the dev
     lane, tooling, and tests, and serves as the executable specification;
   - the **generated native transcriber** (future): the evolution of
     `native_materialize.jac`, generated at seal time, walking the same
     bytes inside the sealed artifact and constructing `ast.*` PyObjects
     through libpython externs, then calling `compile()` and
     `marshal.dumps` at the end of the same GIL-held crossing.

   Both consumers bind the container's class and key tables up front:
   `cir_bind_classes` / `cir_bind_keys` are the `mat_set_class` /
   `mat_set_key` analogs. In the sealed artifact the tables are fixed at
   seal time and registered once at bind; per crossing, instructions refer
   to them by index only.

Why serialize at all if the native side could construct directly? Four
reasons: the sealed producer stays free of libpython and CPython version
churn (only the transcriber tracks CPython); the dev lane and the sealed
lane produce the same bytes, so cross-lane byte equality is a cheap parity
canary; the bytes are cacheable and dumpable for debugging; and the
transcriber stays a bounded, generated, mechanically verifiable component
instead of 4,500 lines of hand-written crossing code.

## 3. Container format

The container is versioned like the JIR container (`compiler/driver/jir.jac`):
magic plus format version, refuse mismatched, no migration attempts.

```
magic          4 bytes  b"JCIR"
format_version u16 LE   CIR_FORMAT_VERSION (currently 1); exact match required
python_version u16 LE   (major << 8) | minor of the producer's CPython;
                        exact match against the running interpreter required
class table    varint count, then per entry: varint byte length + utf8
key table      varint count, then per entry: varint byte length + utf8
string pool    varint count, then per entry: varint byte length + utf8
modules        varint count, then per module:
                 varint path ref (string pool index)
                 varint code length, then the instruction stream bytes
diagnostics    varint count, then per record:
                 u8 severity (0 warning, 1 error)
                 varint refs: code, message, help, mod_path (string pool)
                 varint first_line, col_start, last_line, col_end
terminator     1 byte 0xFE; trailing bytes after it are an error
```

- The **class table** holds `ast` class names (`"Module"`,
  `"FunctionDef"`, `"Load"`, ...). The consumer resolves each against the
  running CPython's `ast` module once per container; an unresolvable name
  is a hard `CodegenIrVersionError` (the producer and the runtime disagree
  about CPython), never a skip.
- The **key table** holds field names (`"body"`, `"targets"`, ...),
  interned once at bind.
- The **string pool** deduplicates every string operand: identifiers,
  string constants, module paths, spliced Python source, diagnostic text.
- Varints are LEB128; signed operands use zigzag.

Version discipline: any change to the opcode set, operand encodings, or
container layout bumps `CIR_FORMAT_VERSION`. A reader that sees a
different version refuses with `CodegenIrVersionError`. There is no
best-effort path. The `python_version` check is exact-minor for now, the
same stance the JIR header takes; marshaled bytecode is per-minor anyway.

## 4. Instruction vocabulary

The instruction stream is a postfix stack machine that builds exactly one
`ast.Module` per module record. Fifteen opcodes in six categories:

| Category | Opcode | Operands | One transcription |
|---|---|---|---|
| Operand push | `OP_NONE` | none | push `None` |
| Operand push | `OP_TRUE` | none | push `True` |
| Operand push | `OP_FALSE` | none | push `False` |
| Operand push | `OP_ELLIPSIS` | none | push `Ellipsis` |
| Operand push | `OP_INT` | zigzag varint (64-bit range) | push int |
| Operand push | `OP_INT_BIG` | sign byte, varint length, LE magnitude | push arbitrary-precision int (decoder normalizes to the same logical op as `OP_INT`) |
| Operand push | `OP_FLOAT` | 8-byte IEEE754 LE | push float |
| Operand push | `OP_STR` | varint string ref | push str from pool |
| Operand push | `OP_BYTES` | varint length, raw bytes | push bytes |
| Aggregate | `OP_LIST` | varint n | pop n values in push order, build a list; splice chunks (see `OP_PARSE_SPLICE`) are flattened inline |
| Aggregate | `OP_TUPLE` | varint n | pop n values, build a tuple; a splice chunk here is a hard error |
| Construction | `OP_NODE` | varint class ref, varint field count, that many varint key refs | pop the field values, call the bound class with those keyword arguments, stamp the location register onto the node, push it |
| Location | `OP_LOC` | 4 zigzag varints, deltas against the previous `OP_LOC` | set the location register (first_line, col_start, last_line, col_end) |
| CPython splice | `OP_PARSE_SPLICE` | varint source ref, varint line offset | `ast.parse` the source, add the offset to every `lineno`/`end_lineno` present (offset 0 means untouched), push an opaque splice chunk of the parsed statement list |
| Framing | `OP_END` | none | stream ends; the stack must hold exactly one value and it must be an `ast.Module` |

Rules that make the vocabulary total:

- **Unknown opcode is a hard versioned error.** The decoder refuses with
  the opcode value, the byte offset, and the container's claimed format
  version ("refusing to guess"). Never a silent skip.
- **The location register must be set before the first `OP_NODE`** of each
  module stream. The writer enforces this at emission and the shim
  enforces it again at transcription.
- **Keyword construction only.** `OP_NODE` never relies on positional
  `_fields` order, because CPython owns that order and changes it between
  versions (`type_params` appeared in 3.12). The producer emits every
  field it wants set; missing-field defaulting is CPython's business.
- **Splice chunks flow only into `OP_LIST`.** The producer cannot know how
  many statements a spliced Python source parses to, so the list builder
  flattens chunks deterministically; a chunk reaching `OP_NODE` or
  `OP_TUPLE` is a format error.
- **Stack discipline is checked twice.** The writer simulates stack depth
  and refuses unbalanced emission at `end_module`; the reader verifies
  again at `OP_END`.

The constant domain of v1 is `None`/`True`/`False`/`Ellipsis`/int/float/
str/bytes plus lists and tuples of those. Complex numbers, frozensets, and
nested constant tuples produced by hypothetical future constant folding
are not encodable in v1; adding them is a format version bump, not a
special case. (Spliced Python source can still yield any constant CPython
can parse, because CPython constructs those itself.)

## 5. Line mapping

`pyast_gen.sync()` stamps four fields on every constructed node from the
jac node's `loc`: `lineno = first_line`, `col_offset = col_start`,
`end_lineno = last_line if last_line > first_line else first_line`,
`end_col_offset = col_end if col_end > col_start else col_start`.

Under JCIR the producer performs that normalization and emits the four
resulting values as `OP_LOC` operands; the shim writes them onto nodes
verbatim. The register model matches `sync()`'s usage pattern: runs of
nodes sharing a jac location cost one `OP_LOC` (delta-encoded, so usually
two or three bytes), and the emission order is child locations first, the
parent's `OP_LOC` immediately before the parent's `OP_NODE`.

The shim performs **no** `fix_missing_locations` pass: that function is a
decision-hiding crutch that would mask producer bugs. A node constructed
with the register unset is a hard error instead. Downstream of the shim,
`compile()` turns these fields into `co_linetable`; CPython owns that
format entirely, which is the whole point of the shim tier.

Spliced statements keep the line numbers `ast.parse` gave them, shifted by
the operand offset. This matches today's behavior exactly: `pyinline_sync`
adds the jac node's `first_line` to inline Python, and the generated stub
sources (interop stubs, sv-to-sv stubs, native test shims) keep their
parse-relative 1..k line numbers with no offset.

### 5.1 The deterministic loc-fill rule

`pyast_gen` reaches for `ast3.fix_missing_locations` in exactly one place
(hoisted lambda-derived defs). The emitter replaces that crutch with a
construction invariant instead of a fill pass:

- Every recipe node is created through one constructor (`nod`) that
  requires a source jac node and stamps the four normalized values at
  construction time, applying `sync()`'s normalization exactly
  (`end_lineno` falls back to `first_line` unless strictly greater,
  `end_col_offset` falls back to `col_start` unless strictly greater).
- A node lowered from a real jac node carries that node's location.
- A synthesized node with no dedicated jac node of its own (glue like
  `Load`/`Store` contexts, operator singletons, `__executed` temporaries,
  hoisted `FunctionDef` shells, preamble imports) inherits the location of
  the jac node whose lowering created it: the pass's current node by
  default, or an explicitly passed jac node where `pyast_gen` passes one
  to `sync()`.
- Consequence: a hoisted lambda def is fully located the moment it is
  built (children from their own jac nodes, shell from the `LambdaExpr`),
  so there is nothing left to fill and no fill pass exists. The
  differential suite's lambda fixture asserts that every location-bearing
  node in the transcribed tree has a concrete `lineno >= 1`, and the micro
  suite asserts the four position fields on every such node of every
  fixture in the corpus.

Two measured exceptions, both front-end debt rather than emitter debt.
Where the jac node the emitter lowers from carries no position of its
own, the rule hands the recipe node a zero, and two kinds reach that
state: an f-string's format-spec `Constant`, and the implicit
`self`/`cls` `arg` of an ability reached through an annex. Both were
measured on the retired Python-AST lane and behave identically there
(`examples/chess/chess.jac` and `examples/mini_todo/bench_local.jac` are
the standing witnesses), so neither is a property of the container. The
micro suite's check argues them by node kind rather than dropping the
rule, and they clear when the front end gives those nodes a position.

One writer convenience supports the rule without changing the wire
format: `CodegenIrWriter.emit_loc_needed` skips the `OP_LOC` when the
location register already holds the node's exact values, so runs of
same-location nodes cost one `OP_LOC` as section 5 promises.

## 6. How diagnostics and the code object cross

The crossing's production result is code objects plus diagnostics; the
container carries both directions of that contract:

- **Producer diagnostics** ride in the diagnostics section as flat records
  (severity, code string, message, help, module path, four location ints).
  Everything `pyast_gen` emits today (E5001..E5098) is a producer decision
  made before the crossing, so those cross as data, exactly like
  `mat_parse_diags` carries `SrcDiag` records. The wire shape `CirDiag`
  mirrors `SrcDiag` (message, code_str, loc, is_error, help) but is
  dependency-free so the format module imports nothing from the parser.
- **Shim diagnostics**: `compile()` failures are caught exactly as
  `pybc_gen` catches them (`ValueError`, `SyntaxError`, `TypeError`) and
  appended as an error diagnostic with code `E5043` and the module path.
  The module simply produces no code object, and the pipeline reports the
  diagnostic as it does today.
- **Hard errors are not diagnostics.** Version skew, malformed bytes,
  unknown opcodes, unresolvable class names, and stack imbalance raise
  `CodegenIrVersionError`/`CodegenIrFormatError`. These mean the artifact
  and the runtime disagree, the same failure class as
  `materialize.jac`'s `_bind_error`, and the correct response is
  "reinstall or rebuild this jac payload", not a source diagnostic.

The Python reference shim exposes both granularities: `transcribe()`
returns `(mod_path, ast.Module)` pairs plus diagnostics for tooling, and
`compile_ir()` returns compiled modules (code object plus
`marshal.dumps` bytes) plus diagnostics for production. Multi-module
programs are one container with one module record per `uni.Module`,
mirroring `pybc_gen.process_modules`.

## 7. What stays tooling-only

Everything below exists today, keeps existing, and never crosses in
production:

- **Full tree materialization**: the `mat_parse` crossing and the
  annotated unitree it rebuilds stay for LSP, `jac tool`, and tests.
- **`gen.py` unparse output**: `exit_module` runs `ast3.unparse` for the
  Python-source view of a module. Tooling lane only.
- **`jac_link` back-references**: the retired Python-AST emitter's
  `sync()` attached `jac_link` (ast node to jac node) for in-process
  consumers. The ast tree dies inside the crossing after `compile()`, so
  production never saw them and nothing outside the emitter read them;
  the cutover retired the attribute with the emitter (section 11.1).
- **`debuginfo` / `jac_mods`**: pass-internal bookkeeping.
- **`py_ast` caches on unitree nodes**: `nd.gen.py_ast` is scaffolding of
  the current pass structure, not part of the crossing contract.

## 8. pyast_gen behavior coverage: IR emission vs shim transcription

"IR emission" means the behavior becomes producer logic whose output is
ordinary JCIR instructions. "Shim transcription" means the behavior is
performed by the shim because it intrinsically requires CPython.

| Behavior | Where | Notes |
|---|---|---|
| `TOKEN_AST_MAP` / `UNARY_OP_MAP` operator lowering | IR emission | zero-field `OP_NODE`s (`Add`, `NotEq`, ...) |
| All statement/expression shapes (if/for/while/try/with/match/assign/calls/comprehensions/f-strings, 130+ exit methods) | IR emission | pure construction recipes; the round-trip suite proves the vocabulary in the small |
| `sync()` location stamping | split | producer computes and emits `OP_LOC`; shim writes fields verbatim; `compile()` owns `co_linetable` |
| Symbol mangling (`_py_name`, `__init__`, `py_ctx` Load/Store/Del) | IR emission | string and context-class choices are decisions |
| Preamble assembly (`__future__` import, jaclib/builtin/typing dedup, enum kind imports) | IR emission | producer keeps the same accumulator sets and emits the final import statements |
| Module docstring placement and `__name__ == "..."` guards | IR emission | ordering (docstring before `__future__`) is producer-owned |
| `TYPE_CHECKING` wrapping of typed imports | IR emission | an `If` node plus a typing import |
| Switch lowering, walker visit/disengage/report lowering, edge/connect lowering, `OpenStmt` region try/finally | IR emission | multi-statement recipes, all ordinary nodes |
| Temp and lambda naming (`__jac_temp_N`, `_jac_lambda_N`), hoist frames, leak diagnostics (E5098) | IR emission | placement decisions happen before emission; see fidelity note 3 on `fix_missing_locations` |
| Scope directives (`Global`/`Nonlocal`, sorted) | IR emission | |
| Semstr decorators (`_get_sem_decorator`), `jac_test` decorators, `impl_patch_filename` decoration | IR emission | decorator `Call` nodes with `Constant` operands; the `is_test(mod_path)` predicate moves producer-side |
| Enum lowering (`Enum`/`IntEnum`/`StrEnum` choice, `auto()` values) | IR emission | |
| Has-var lowering (`field(init=False)`, `field(factory=lambda: ...)`, constant fast path) | IR emission | see fidelity note 2 |
| `PyInlineCode` (`::py::` blocks) | shim transcription | `OP_PARSE_SPLICE` with the jac first_line as offset; `textwrap.dedent` is a producer-side string op |
| Native interop stubs, sv-to-sv stubs, boundary stub classes, native test shims, registration map | shim transcription | producer builds the Python source text from the interop manifest (sealed-side data); shim parses via `OP_PARSE_SPLICE` with offset 0 |
| `compile()` + `marshal.dumps` (all of pybc_gen) | shim transcription | end of the same crossing |
| `ast3.unparse` into `gen.py` | tooling only | never crosses |
| Diagnostics E5001..E5098 | IR emission | cross as `CirDiag` records |
| E5040 (missing py_ast) | retired | the failure class becomes a container format error |
| E5043 (compile failure) | shim transcription | same exception tuple, same code |

## 9. Fidelity analysis

Behaviors with subtle semantics, and where each one lands. Honesty over
completeness: anything unresolved is listed in section 10, not silently
assumed away.

1. **`impl_patch_filename`.** Applied to abilities whose body is an
   `ImplDef` (operand: the impl file's `mod_path`) and to tests in
   `is_test` files (keyword operand `file_loc`). Both are `Call` decorator
   nodes with string constants: fully IR-encodable. The decision inputs
   (impl file paths, the `is_test` predicate from `ext_registry`) are
   producer-side facts.
2. **Has-var `field()` wrapping.** Resolved in the phase 1 emitter, and
   more directly than predicted: the emitter's recipe tree preserves the
   predicate exactly. The constant-vs-factory choice becomes "is the
   value's recipe a `Constant` node", which is the same decision
   `isinstance(value_expr, ast3.Constant)` makes on the constructed ast,
   with no unitree re-derivation needed. Covered by the archetype fixture
   in the differential suite.
3. **Hoisted lambdas and `fix_missing_locations`.** Resolved: the
   deterministic loc-fill rule is specified in section 5.1, implemented as
   a construction invariant in `jcir_gen_pass` (no fill pass exists), and
   verified by the differential suite's nested-lambda fixture (lambdas in
   default arguments included).
4. **Jsx lowering.** The old `PyJsxProcessor` made real decisions
   (element lowering, attribute handling, text/expression children) and
   its output was ordinary `ast3` nodes, so the vocabulary covered it.
   The emitter ported those decisions into its own `exit_jsx_*` methods
   and the processor retired with the emitter. The `EsJsxProcessor` that
   shared its file targets the ECMAScript lane, which does not cross this
   boundary at all, and stays.
5. **`__jac_dirty_fields__`-adjacent emissions.** Verified: `pyast_gen`
   emits nothing dirty-field-related; that tracking lives at runtime in
   the `track_writes` hook installed when an anchor becomes persistent.
   The adjacent codegen behaviors are the
   `field()` wrappers (note 2) and `__jac_async__` class markers, both
   ordinary IR emission. Nothing crosses.
6. **Module docstrings.** `nd.doc` becomes the first `Expr(Constant)`
   before the preamble; the ordering decision is the producer's and the
   round-trip suite asserts `__doc__` survives compilation.
7. **`TYPE_CHECKING` blocks.** Producer wraps typed-import statements in
   `If(Name("TYPE_CHECKING"))` and adds the typing import to the preamble.
   Encodable; no shim involvement.
8. **Generated-source stubs and `jac_link` hygiene.** The old stub
   generators walked their parsed output setting `jac_link = []` so
   downstream tooling would not confuse them with jac-linked nodes. The
   shim's splice sets no `jac_link` at all, which is the
   production-correct behavior (nothing downstream of the crossing reads
   it), and with the cutover it is the only behavior: the attribute is
   gone from the tree.
9. **Shared ast subtrees.** `resolve_switch_stmt` reuses one
   `executed_assign` node across case bodies. JCIR duplicates the
   construction; `compile()` treats a shared node and an equal copy
   identically. No memo table exists on purpose (section 2).
10. **Interned keys and classes.** Binding once per container mirrors
    `mat_set_key`'s `sys.intern` discipline, keeping per-node kwarg
    construction allocation-free in the native transcriber.
11. **Kwargs construction on future CPythons.** The reference shim calls
    the bound class with the complete keyword set the producer emitted, so
    the CPython 3.13+ deprecation of constructing ast nodes with missing
    required fields never fires as long as producers emit full field sets,
    which `pyast_gen` already does everywhere. The suite passes on the
    bundled 3.14.

## 10. Unresolved questions

- **The `fix_missing_locations` replacement rule** (fidelity note 3):
  resolved, see section 5.1.
- **Producer-side constant predicate** for has-var lowering (fidelity
  note 2): resolved, the recipe tree preserves the predicate directly.
- **`Ellipsis` cannot be the recipe's own value.** `unitree` exports an
  `Ellipsis` node class, so inside any pass that imports the unitree
  vocabulary the bare name is that class rather than the builtin, and an
  identity test against it silently never matches. The producer therefore
  puts a marker object (`CgEllipsis`) in the recipe where the singleton
  would go, and `write_ir_value` recognizes it by type and emits
  `OP_ELLIPSIS`. The native lane wants the same shape for its own reason:
  the singleton has no native value, so a method that constructs one
  demotes. Anything else that has to travel as an opcode rather than a
  constant belongs in the same pattern.
- **Marshal bytes are not a stable parity token.** Found while building
  the differential suite: `marshal.dumps` sets a per-object `FLAG_REF`
  bit based on the object's transient refcount at serialization time, so
  two semantically identical code objects can marshal to different bytes
  depending on the call shape around `dumps`. The end-to-end parity
  canary must therefore compare code objects field by field (recursively
  through `co_consts`) or normalize before comparing, never raw
  `marshal.dumps` output from different call sites. The differential
  suite's `code_diffs` helper is the reference comparison.
- **`gen.py` consumers audit.** Done at the cutover. Every reader of
  `mod.gen.py` is tooling (`jac tool ir py`, the transform and eject
  commands, the publish vendor and builder, the mcp compiler bridge) and
  every reader of `mod.gen.py_ast` takes the module root, which the shim
  seat supplies. The one interior-node reader was unitree's
  `DeleteStmt.py_ast_targets`, whose only caller was the retired emitter;
  it went with it, and took a seal waiver with it.
- **Structured diagnostics.** `CirDiag` carries flat strings; the
  diagnostics registry objects (severity policies, fix-its) stay
  Python-side. If the sealed pipeline ever needs to emit a diagnostic kind
  the flat record cannot express, that is a format version bump.
- **Exact-minor `python_version` is now a baked fact.** `sys.version_info`
  does not lower, so the stamp comes from `jcir_facts.JCIR_PYTHON_MAJOR`
  and `JCIR_PYTHON_MINOR` through `jcir_python_version()`. The container
  still stamps and still refuses on a mismatch; the refusal now compares
  against the minor the build targets rather than the minor the reader
  happens to run under, and `test_jcir_facts_sync.jac` pins the baked
  target to the interpreter running the build. A cross-minor mismatch
  therefore fails at build time instead of on the first container read.
  Relaxing the exact match to a range still waits on the native
  transcriber and a per-minor parity canary.
- **Field-set completeness is not validated at bind time.** A producer
  that omits a field CPython requires surfaces as a `compile()` error
  (E5043) rather than a bind error. Acceptable for now because the parity
  canary compares final code objects per CPython minor; revisit if the
  failure mode is ever observed in the wild.
- **`OP_TUPLE` currently has no producer.** It exists because tuple-valued
  ast fields are a plausible near-term need and its transcription is
  unambiguous; if v2 arrives without a use, drop it.
- **Not every demoted name can be waived.** The seal's load canary
  resolves every name the layout advertises. A demoted *method* ships as
  an `abort()` stub and resolves, and so does a demoted module-level
  function of the root module itself -- `module_facts`'s waived
  `client_capability_violations` is the standing example. Two kinds get
  no stub and so are advertised and absent, which fails `dlopen`: a
  nested function inside a demoted method, and a module-level function of
  a *dependency* in the closure. The jcir seal hit all four at once
  (`set_ctx`, `get_pieces`, `decode_ops`, `read_container`). Nested
  functions hoist to methods; a dependency function must lower or leave
  the closure, never be waived. `decode_ops` was the latter: it decodes
  into heterogeneous tuples, does not lower, and now lives in
  `codegen_shim` where the reader belonged anyway.
  `test_sealed_demotion_audit.jac` and `test_jcir_seal_baseline.jac` fail
  on such a waiver now, so the finding surfaces in the coverage report rather than
  three minutes into a link.
- **Nested functions and the emitter's internal refusal.** Two emitter
  methods refused with an emitter-internal error rather than a named gap.
  Hoisting a nested function to a method cleared one of them
  (`exit_delete_stmt`); the other (`_query_filter_kws`) does not move
  under any reshaping of union locals, `any` locals, conditional
  expressions or continue-guards, which places that fault in the native
  emitter. Nested-function lowering is the first place to look.

## 11. Module placement

- `compiler/backends/py/codegen_ir.jac`: the format module is
  bootstrap-tier (covered by `bootstrap_manifest.py`) like `jir.jac`, its
  container sibling in `compiler/driver/`, because it is a leaf (imports only
  `struct`/`sys`), both lanes need it (the seal-time emitter generator
  consumes the same constants), and the consumer must load in the runtime
  core without the full compiler.
- `compiler/backends/py/codegen_shim.jac`: the Python-side consumer, beside the format
  it consumes, mirroring how `parser/materialize.jac` sits beside the
  parser it binds. It uses `import ast` freely: the shim IS the Python
  side, and this module is never sealed. `decode_ops` lives here rather
  than in `codegen_ir` for the same reason: it decodes into
  heterogeneous tuples, which does not lower, and as a module-level
  function it cannot be waived (section 10). `codegen_ir` keeps
  `read_container`, which does lower, so the writer and the container
  reader both reach zero seams.
- One bootstrap-dialect note: the bootstrap tier (the seed modules
  declared in `bootstrap_manifest.py`, the shim included) is compiled by
  the jac0 bootstrap,
  which has no `**kwargs` call splat, so the shim builds its single
  keyword-apply trampoline through one `eval` of a two-argument lambda at
  first use. The generated native transcriber has no such constraint (it
  builds a kwargs dict through the C API).
- `compiler/backends/py/jcir_gen_pass.jac` (+impl): the emitter pass.
  Lane-portable jac with no CPython ast import anywhere; it ports
  `pyast_gen`'s decisions method by method into recipe construction
  (`CgNode` trees: class name, field names, field values, one normalized
  location per node, `CgSplice` markers for `::py::` splices) and
  serializes the finished module recipe through `CodegenIrWriter`, also
  stashing the container on the module's `gen.jcir` for the pipeline
  consumer. The recipe tree is the emitter's working form; the wire
  format is unchanged. Phase 2 added the object-spatial surface (walkers,
  event signatures with `on_entry`/`on_exit` and `set_trigger`, visit
  with else, disengage, report, skip, spawn, connect and disconnect
  operators, edge reference chains via `GraphQuery`/`QHop`/`QPred`,
  filter and assign comprehensions, typed context blocks, `root`), match
  statements, and async (abilities, for, with, await, `__jac_async__`
  archetypes). Phase 3 added interop manifest emission (native export
  stubs, the import registration map, sv-to-sv stubs, native test shims;
  all via `OP_PARSE_SPLICE` exactly as section 8 planned, with producer
  bookkeeping of splice-bound names for registration placement),
  sem-string decorators, llm ability bodies (`get_mtir`/`call_llm`
  recipes, the `by` operator), and concurrency flow/wait. Phase 4 ported
  jsx lowering per the PyJsxProcessor audit (element lowering to jaclib
  `jsx(tag, attrs, children)` calls, component-vs-tag element names,
  spread-attribute Dict merging, attribute and text entity unescaping,
  fragments, slots, comments). The single remaining refusal is genai
  call expressions, which both lanes now refuse deliberately (the
  emitter with its NotImplementedError naming the construct and
  location, `pyast_gen` with its "temporarily disabled" ice; the parser
  currently never produces the construct, and the differential suite
  pins both refusals on a synthetic node).

  Sealed-lane producer caveats, all but one resolved. The builtin-name
  set and the ambient typing names are baked into `jcir_facts.jac` and
  pinned against their sources by `test_jcir_facts_sync.jac`;
  `textwrap.dedent` lowers through the na_stdlib shim, which joins the
  measured closure and contributes zero seams; the CPython minor joins
  the same baked facts (section 10). What remains is `html.unescape` for
  jsx text and string attributes, waived as
  `_JCIR_ENTITY_SEAM_WAIVERS`. It clears with an na_stdlib `html` shim
  carrying the full html5 entity table, pinned against `html.unescape`.
  A reduced table is not acceptable: the two lanes must agree byte for
  byte, so a missing entity is a silent divergence rather than a missing
  feature.

  The emitter is a **sealed** native seal root, with an empty reachable
  waived set. It was refused for three natively-reachable stubs and all
  three cleared. Moving the interop stub generation off `enter_node`
  into `exit_module` took `_gen_native_interop_stubs` and, with it,
  unitree's `gen` accessor, because that call was the only native path
  reaching a `gen` read. `exit_func_call` cleared when its chunked-flow
  question -- the mangled receiver type of an `x.chunks(n)` call --
  became `FuncCall.chunks_recv_type`, stamped in `type_checker_pass`
  beside `call_kind`. Reading a type-system object is Python-only by
  construction, so the decision had to arrive as data; it is a new field
  rather than a new `call_kind` value because the native and ecmascript
  emitters branch on that field's existing values.

  Building it is the most expensive root from cold: 3m26s for the
  artifact, 3m50s with its container crossing canary. Under the
  sha-incremental reuse a warm seal of an unchanged tree costs about
  2.2s in a fresh process, nearly all of it (about 2.08s) re-deriving
  the materializer root through `generate_materialize_root`, which is
  the next thing worth caching. `seal_native_artifacts` builds the one
  fused `libjac_compiler` library whose closure carries the emitter
  (`codegen_ir`, `jcir_facts`, and the rest of the compiler closure),
  and the artifact passes a load canary and a container crossing canary
  before it is accepted. `test_jcir_seal_baseline.jac` pins the
  emitter's clean members; the residual seams are waived by family in
  `NATIVE_SEAL_WAIVER_FAMILIES`, each naming what clears it, and
  `test_sealed_demotion_audit.jac` holds the whole seal to that,
  refused modules included: withholding a module from the fused root
  does not withhold the accounting (`NATIVE_SEAL_REFUSED_MODULES`).

  The sealed-versus-source byte comparison C2 could not run still
  cannot. This paragraph once said the pass-serving binder is the
  crossing, so that `JcirGenPass.ir_bytes()` executes inside the
  artifact once `native_artifact_for` reports it. The #8288 M1 crossing
  measurement said otherwise: the binder opens, verifies and probes the
  artifact and then retains the engine and **no function pointer**, and
  `_require_native_pass_tier` falls through to the pass's bytecode body.
  Both sides of that comparison are the source lane.
  `test_jcir_bound_emitter_bytes.jac` (renamed from
  `test_jcir_sealed_bytes.jac`, which promised what it could not check)
  therefore claims exactly three things: the real artifact builds and
  binds, the binder registers the module, and the container bytes do not
  change when it is bound -- binding attests an artifact and must not
  perturb it. Its last test pins the limitation as a mechanism rather
  than as prose, by observing that the Python body still runs; it fails
  the day the artifact serves the pass, which is M1 rung 3's acceptance.
- `compiler/backends/py/jcir_bc_gen_pass.jac` (+impl): the shim-seat pipeline
  pass. Reads `gen.jcir`, transcribes through the reference shim into
  `gen.py_ast`, unparses the tree into `gen.py` (so tooling consumers of
  the Python-source view keep working under the flag), and compiles into
  `gen.py_bytecode`. It is the Python side of the crossing (imports ast
  freely, never sealed) and makes no codegen decisions.
- Tests: `tests/compiler/test_codegen_ir.jac`, string-named, covering the
  full round trip (functions with args and defaults, assignments, calls, a
  class, if/for, f-string), `ast.dump` equality against the source tree,
  hand emission without `ast` on the producer seat, splice offsets,
  version refusal, unknown-opcode refusal, diagnostics transport, and
  writer stack discipline; plus `tests/compiler/test_jcir_gen_pass.jac`,
  the differential suite that compiles fixtures through both codegen
  lanes and asserts exact `ast.dump(include_attributes=True)` equality,
  recursive code-object equality after `compile()`, and behavioral
  equality under `exec`, including one real compiler source file
  (`compiler/frontend/srcloc.jac`) end to end.

### 11.1 The codegen tail, after the cutover

`get_py_code_gen` (compiler/driver/compiler.jac) returns one Python codegen
tail and there is nothing to select between:

- `JcirGenPass`, `JcirBytecodeGenPass`

Codegen decisions run through the emitter, the container crosses as bytes
on `gen.jcir`, and the shim-seat pass rebuilds `gen.py_ast`, `gen.py` and
`gen.py_bytecode` from those bytes, so every downstream consumer of the
standard artifacts keeps working.

The `JAC_CODEGEN` environment variable that selected this lane while it
was being built is gone, along with the Python-AST emitter, its bytecode
pass, and `PyJacAstLinkPass`. Two consequences are worth stating plainly
rather than discovering:

- `jac_link` back-references no longer exist anywhere. They were a
  tooling-only handle from a CPython ast node back to the jac node that
  produced it (section 7), attached by the old emitter's `sync()`. The
  tree the shim seat builds dies inside the crossing after `compile()`,
  so nothing downstream held one in production; the micro suite's
  per-node assertion is now the loc-fill invariant of section 5.1
  instead, which is the property `sync()` was actually enforcing.
- Constructs the emitter refuses (section 11) fail the compile loudly
  rather than lowering. There is no second lane to fall through to, which
  is the point: a refusal is a named gap with a test, not a silent
  divergence between two emitters.

### 11.2 The payload-lane canary manifest

The nineteen suites below were validated end to end on this lane while it
still lived behind a flag, including a full from-clean-cache build of the
dev CLI toolchain itself. They now need no flag and no special job: they
are the default lane, and CI's ordinary chunks collect all nineteen --
`tests/compiler/test_*.jac` and the `tests/compiler/passes` trees in the
compiler lane, `tests/` minus `tests/compiler` in the runtime lane.

`tests/compiler/test_jcir_canary_manifest.jac` holds the list and pins
what prose cannot: that every named suite still exists, that every one
still falls inside a CI collection glob, and that the lane they measure
is the container. A canary that is renamed out of the matrix fails there
rather than going quiet.

- tests/compiler/test_compilation.jac
- tests/compiler/test_codegen_ir.jac
- tests/compiler/test_jcir_gen_pass.jac
- tests/compiler/test_importer.jac
- tests/compiler/test_archetype_runtime.jac
- tests/compiler/test_client_codegen.jac
- tests/compiler/test_codespace_inference.jac
- tests/compiler/test_placement_evidence.jac
- tests/compiler/test_interop_manifest.jac
- tests/compiler/test_front_end_native_idioms.jac
- tests/runtimelib/test_graph_query.jac
- tests/runtimelib/test_osp_edges_contract.jac
- tests/runtimelib/test_closures.jac
- tests/runtimelib/test_serve.jac
- tests/runtimelib/test_serve_bridged_endpoints.jac
- tests/runtimelib/test_client_bundle.jac
- tests/langserve/test_server.jac
- tests/language/test_language.jac
- tests/language/test_bugs.jac

The one standing exclusion is gone with the flag: `test_micro_suite.jac`
was held back because it asserted `jac_link` on every generated node.
That assertion is now the section 5.1 position check, and the suite runs
on this lane like every other.

## 12. Cutover fit

JCIR is stable across sealed and dev lanes by construction: the codegen
decision pass emits the same bytes whether it runs natively or in Python,
so lane parity is byte equality on the container, and end-to-end parity is
code object plus diagnostics equality against the bytecode pipeline, per
the epic's canary. The waiver discipline and payload-lane proofs of #8139
were retired with the seal (#8732); the format itself is unchanged, and
it is the piece that lets a native emitter and a bytecode transcriber
share one contract.
