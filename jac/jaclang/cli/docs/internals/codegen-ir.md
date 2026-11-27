# Python Codegen (JCIR)

Status: shipped. This is the compiler's only Python codegen. The emitter
(`compiler/backends/py/jcir_gen_pass.jac`) lowers the annotated unitree into a
recipe tree and builds a CPython `ast.Module` from it in memory; the bytecode
pass (`compiler/backends/py/jcir_bc_gen_pass.jac`) compiles that tree into a
code object.

History: JCIR began as a byte container (a varint-encoded postfix
instruction stream with class, key and string tables) so that a native
compiler kernel could run the emitter and hand its output to a Python-side
transcriber. The kernel was removed, the compiler runs as Python bytecode, and
the bytes were written and decoded in the same process without ever being
stored, so the byte format, its writer and its decoder were deleted. The
emitter's recipe tree, which was always its working form, now becomes the
`ast` tree directly.

## 1. The codegen tail

The `PY_IR` and `BYTECODE` products (`compiler/driver/pipeline.jac`) are one
Python codegen tail with nothing to select between:

- `JcirGenPass` makes every lowering decision, builds the module recipe, and
  stores the resulting `ast.Module` on `module.gen.py_tree`.
- `JcirBytecodeGenPass` compiles `gen.py_tree` with
  `compile(tree, mod_path, "exec", dont_inherit=True)`, publishes the tree as
  `gen.py_ast`, and stores `marshal.dumps` of the code object as
  `gen.py_bytecode`.
- `generated_python` (`compiler/backends/py/codegen_shim.jac`) unparses
  `gen.py_ast` on demand for tooling (`jac tool ir py`, the transform and eject
  commands, the mcp compiler bridge). The Python source view is never built on
  the run path.

When a module has blocking errors, `drop_products_on_error`
(`compiler/driver/module_compile.jac`) clears `gen.py_tree` and
`gen.py_bytecode` so nothing runnable survives.

## 2. The recipe tree

The emitter never imports CPython `ast` classes into its decisions. It builds
records:

- `CgNode`: an `ast` class name, parallel lists of field names and field
  values, and one normalized location (`l1`, `c1`, `l2`, `c2`). Every node is
  created through `JcirGenPass.nod` (or `nod_loc` with explicit positions).
- `CgSplice`: generated Python source (native interop stubs, the import
  registration map, sv-to-sv stubs, native test shims). It is parsed with
  `compile(..., ast.PyCF_ONLY_AST)` and its statements are flattened into the
  enclosing list. A splice anywhere other than a list element is an error.
- `CgEllipsis`: a marker for the `Ellipsis` constant. The unitree exports an
  `Ellipsis` node class, so inside the emitter the bare name is that class, not
  the builtin; the marker sidesteps the shadowing.
- `CgWideInt`: an integer literal or comptime integer too wide for 64 bits,
  carried as a sign and a little-endian magnitude.

The value domain is `None`, the markers above, `CgNode`, `bool`, `int`,
`float`, `str`, `bytes`, and lists of those. `build_py_value` maps it onto
`ast` objects:

- Each `CgNode` becomes `getattr(ast, cls)(**fields)`. Construction is by
  keyword only, never by positional `_fields` order, because CPython owns that
  order and changes it between versions. Field names and values must pair up
  exactly.
- The four location fields are written onto every constructed node verbatim.
- Scalars are normalized to the exact builtin type (`int`, `float`, `str`,
  `bytes`, `True`/`False`), so an enum member or other subclass never reaches
  `ast.Constant`.
- Anything outside the domain raises `ValueError` naming the problem; a
  producer put a live Python object where a recipe value belongs.

`build_py_module` requires the root to build an `ast.Module`.

No memo table exists. Where the emitter reuses one recipe node in two places,
each use is built as its own `ast` object; `compile()` treats a shared node and
an equal copy identically.

## 3. Locations

The emitter stamps four fields on every node from the jac node's `loc`:
`lineno = first_line`, `col_offset = col_start`,
`end_lineno = last_line if last_line > first_line else first_line`,
`end_col_offset = col_end if col_end > col_start else col_start`.
`compile()` turns these into `co_linetable`; CPython owns that format.

Spliced statements keep the line numbers the parse gave them (1..k within the
generated stub source).

### The loc-fill rule

There is no `ast.fix_missing_locations` pass. Location is a construction
invariant instead:

- A node lowered from a real jac node carries that node's location.
- A synthesized node with no jac node of its own (`Load`/`Store` contexts,
  operator singletons, `__executed` temporaries, hoisted `FunctionDef` shells,
  preamble imports) inherits the location of the jac node whose lowering
  created it: the pass's current node by default, or an explicitly passed jac
  node.
- So a hoisted lambda def is fully located the moment it is built, and there
  is nothing left to fill. The differential suite's lambda fixture asserts a
  concrete `lineno >= 1` on every location-bearing node, and the micro suite
  asserts the four position fields on every such node of every fixture.

Two measured exceptions are front-end debt rather than emitter debt: an
f-string's format-spec `Constant`, and the implicit `self`/`cls` `arg` of an
ability reached through an annex, both carry a zero because the jac node they
lower from has no position. The micro suite argues them by node kind, and they
clear when the front end gives those nodes a position.

## 4. Diagnostics

- Emitter diagnostics (E5001..E5102, W5096) are emitted directly through the
  pass context while lowering.
- `compile()` failures (`ValueError`, `SyntaxError`, `TypeError`) become
  `E5043` on the module, which then has no bytecode.
- `E5040` fires when a module reaches the bytecode pass with neither a tree nor
  bytecode.
- A malformed recipe (unknown `ast` class, a field-name/value mismatch, a value
  outside the domain, a misplaced splice) raises from `build_py_value` while
  the emitter runs. That is a compiler bug, not a source diagnostic.

## 5. Fidelity notes

1. **`impl_patch_filename`.** Applied to abilities whose body is an `ImplDef`
   (operand: the impl file's `mod_path`) and to tests in `.test.jac` files
   (keyword operand `file_loc`). Both are decorator `Call` nodes with string
   constants; the `is_test` predicate is baked as
   `jcir_facts.jcir_is_test_path`.
2. **Has-var `ObjectField()` wrapping.** The constant-versus-factory choice is
   "is the value's recipe a `Constant` node", the same decision the retired
   Python-AST emitter made on the constructed tree.
3. **Jsx lowering.** Element lowering, attribute handling and text or
   expression children live in the emitter's `exit_jsx_*` methods and produce
   ordinary nodes.
4. **Module docstrings.** `nd.doc` becomes the first `Expr(Constant)` before
   the preamble; the round-trip fixture asserts `__doc__` survives.
5. **`TYPE_CHECKING` blocks.** Typed imports are wrapped in
   `If(Name("TYPE_CHECKING"))` with the typing import added to the preamble.
6. **Kwargs construction on newer CPythons.** The builder passes the complete
   field set the emitter produced, so the 3.13+ deprecation of constructing
   nodes with missing required fields does not fire as long as the emitter
   emits full field sets.
7. **Marshal bytes are not a parity token.** `marshal.dumps` output depends on
   object identity and refcounts at dump time (shared or interned strings set
   `FLAG_REF`), so semantically identical code objects can marshal
   differently. Compare code objects field by field, recursing through
   `co_consts`, as the differential suite's `code_diffs` does.
8. **The single refusal.** Genai call expressions refuse with a
   `NotImplementedError` naming the construct and location; the parser
   currently never produces them, and the differential suite pins the refusal
   on a synthetic node.

## 6. Baked facts

`compiler/backends/py/jcir_facts.jac` holds the runtime builtin names, the
ambient typing names, and the test-path predicate the emitter reads as data.
`tests/compiler/test_jcir_facts_sync.jac` pins each against its source of
truth (`runtime.builtin.__all__`, `typing_ambient.pyi`, `ext_registry.is_test`)
and checks that every operator-map key is a real `Tokens` member.

## 7. Tests

`tests/compiler/test_jcir_gen_pass.jac` is the differential suite. Every
fixture is emitted twice over the same module, once by the pipeline and once
by a fresh `JcirGenPass` over the already-compiled module
(`JcirGenPass.ir_module`), and the suite asserts exact
`ast.dump(include_attributes=True)` equality, recursive code-object equality
after `compile()`, and behavioral equality under `exec`. It includes real repo
files (`compiler/frontend/srcloc.jac`, `examples/jaclang_org/core/social_graph.jac`)
end to end, pins that the codegen schedule carries no second Python emitter,
and unit-tests the builder directly on a splice and a wide integer.
