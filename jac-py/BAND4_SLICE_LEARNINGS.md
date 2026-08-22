# Band 4 slice learnings (JacPython native compiler)

**Read this before touching Band 4 function work.** Each slice is a separate commit/PR.
Do not combine slices. Do not re-derive facts already captured here - verify against
oracle fixtures and extend the patterns below.

Last updated: 2026-08-17 (`jac-python` through `89320d8e6`).

---

## 1. Two-axis maturity (do not conflate)

| Axis | Status on Band 4 HEAD |
|------|------------------------|
| **VM/runtime** (`pyc_first.jac`, `objects.jac`) | Broad: closures, defaults, `*args`/`**kwargs`, calls, most opcodes already work when fed **host-compiled** PyCode |
| **Native compiler** (`compiler_codegen.jac`, …) | Narrow: slices land incrementally; oracle parity is the gate |

A slice is “done” when **native source → native compile → JacPython VM** matches CPython
oracle on the slice fixture - not when the VM happens to execute similar bytecode from
host compile.

---

## 2. Global invariants (all Band 4 slices)

### 2.1 Pipeline entry points

```text
  source → tokenizer → parser → validate → symtable → compile_exec/compile_function_cfg
         → verify_cfg → assemble → exec_code
```

- Product path: `product_compile.jac` / `layer9_product_exec.jac` (`product_exec(src)`).
- Compiler unit tests: `compiler_slice.jac` (`compile_parsed_exec(src)`).
- Oracle: `host_oracle.host_compile_marshal` → `unmarshal` (independent of native compiler).

### 2.2 Test pattern (copy for every new slice)

Each slice adds **paired** tests in:

1. `jac-py/jacpython/compiler_slice.jac` - parse + compile path, nested `co_code` oracle
2. `jac-py/jacpython/layer9_product_exec.jac` - full product path + VM execution

Minimum assertions per slice:

| Check | Where |
|-------|--------|
| Nested function `co_code ==` oracle | `compiler_slice` |
| `stacksize`, `argcount`, `varnames`, `flags` | both |
| VM `result ==` expected | both (`exec_code` / `product_exec`) |
| Symtable oracle | only when capture/defaults/enclosing scope is new |

Helpers already exist - **do not reinvent**:

- `compile_parsed_exec`, `first_nested_code`, `oracle_exec` - `compiler_slice.jac`
- `product_exec`, `assert_matches_oracle` - `layer9_product_exec.jac`

### 2.3 Files by concern

| Concern | Primary files |
|---------|----------------|
| Codegen / bytecode | `compiler_codegen.jac` |
| Scope / params / freevars | `compiler_symtable.jac` |
| Parser actions (handwritten) | `parser_actions.jac` |
| Generated parser | `parser.jac` (regen via `grammar2jac.py`) |
| Tokenizer | `tokenizer.jac`, `layer5_tokenizer.jac` |
| VM opcode smoke (host PyCode) | `layer_vm_conformance.jac`, `vm_opcode_fixtures.py` |
| Product gates | `layer9_product_exec.jac` |

### 2.4 CPython 3.14 codegen conventions (already wired)

- **Fast locals**: `LOAD_FAST_BORROW` / `STORE_FAST` via `emit_name_load` / `emit_name_store`.
- **Globals at call sites**: `LOAD_GLOBAL` uses `(name_index << 1) | 1` NULL folding - no separate `PUSH_NULL`.
- **Function flags baseline**: `CO_OPTIMIZED | CO_NEWLOCALS` (= 3).
- **Function prologue** (`emit_function_prologue`): `MAKE_CELL` per `cellvars`, then `COPY_FREE_VARS` if `freevars`, then `RESUME`.
- **Nested function creation** (`emit_make_function_with_closure`): see §2.5.
- **Termination**: `visit_if` must propagate `terminated` when an if-arm ends in `return` - otherwise a spurious `LOAD_CONST None; RETURN_VALUE` epilogue appears after `RETURN_VALUE`.
- **If/while tests**: single compares use bool-context `COMPARE_OP` in `visit_test_expr` (no extra `TO_BOOL`).

### 2.5 `MAKE_FUNCTION` attribute stack order (critical - do not reorder)

CPython stack bottom → top before `MAKE_FUNCTION`:

1. Optional **defaults tuple** (positional defaults)
2. Optional **kwdefaults dict** (kw-only defaults)
3. Optional **closure tuple** (free vars from enclosing scope)
4. **`LOAD_CONST` nested code**

`SET_FUNCTION_ATTRIBUTE` pops **top-first** (LIFO). Emission order in
`emit_make_function_with_closure`:

```text
  … push tuples/dict …
  LOAD_CONST co
  MAKE_FUNCTION
  SET_FUNCTION_ATTRIBUTE 8   # closure (if any)
  SET_FUNCTION_ATTRIBUTE 2   # kwdefaults (if any)
  SET_FUNCTION_ATTRIBUTE 1   # defaults (if any)
```

Attribute arg meanings (VM in `pyc_first.jac`): `1` = defaults tuple, `2` = kwdefaults dict, `8` = closure tuple.

### 2.6 Localsplus / `varnames` parameter order (critical)

`sym_visit_params` appends `DEF_PARAM` names in this order (matches CPython + VM
`exec_code_frame` in `pyc_first.jac`):

```text
  posonlyargs → args → kwonlyargs → *vararg → **kwarg
```

Then `fast_varnames_from_sym` appends non-parameter locals (sorted).

**VM layout** (`pyc_first.jac`):

- Slots `[0 .. argcount)`: positional parameters (posonly + regular)
- Slots `[argcount .. argcount+kwonlyargcount)`: kw-only parameters
- Next slot: `*args` if `CO_VARARGS`
- Next slot: `**kwargs` if `CO_VARKEYWORDS`

`argcount` = `len(posonlyargs) + len(args)` - **does not** include kw-only, `*args`, or `**kwargs`.

### 2.7 Symtable closure model (critical for recursion + closures)

In `sym_analyze_block` (`compiler_symtable.jac`):

- Only **function-like** blocks contribute their locals to `newbound` passed to children.
- **Module/class locals are NOT** added to `newbound` for nested functions.
- Effect: top-level `def fact(n): return fact(n-1)` uses **`LOAD_GLOBAL`** for self-call, not `LOAD_DEREF`.
- Nested capture: free names in child → parent promotes to `SCOPE_CELL`; child gets `SCOPE_FREE`.

Default expressions are visited in the **enclosing** scope via `sym_visit_arg_defaults` (positional + kw-only defaults).

### 2.8 Decorators

Implemented in Slice 7 (`95db02261`). `visit_function_def` evaluates `decorator_list` in enclosing scope, emits `MAKE_FUNCTION`, then applies decorators bottom-up via `CALL 0` (CPython 3.14 self_or_null slot). Do not reintroduce the old `NotImplementedError` guard.

### 2.9 When to touch parser / tokenizer

| Symptom | Likely fix location |
|---------|---------------------|
| `def` parse fails / wrong `arguments` AST | `parser_actions.jac`, maybe `grammar2jac.py` + regen `parser.jac` |
| Hang on `def …\n\nstmt` | `tokenizer.jac` blank-line advance (see thin slice) |
| `grammar2jac.py --check` fails | regen `parser.jac`; fix `grammar2jac.py` translator, not hand-edit generated rules |

After any parser change: `python3 jac-py/tools/grammar2jac.py --check`.

### 2.10 VM fixtures vs compiler slices

Closure opcodes (`MAKE_CELL`, `LOAD_DEREF`, `STORE_DEREF`, `COPY_FREE_VARS`, `BUILD_TUPLE`,
`SET_FUNCTION_ATTRIBUTE`) were added in commit `e573b5857` **before** the closures slice
needed them for codegen parity. **Do not re-add VM support** - extend `layer_vm_conformance`
only if a **new opcode** appears in native emission.

---

## 3. Slice catalog

Status key: **CLOSED** = committed on `jac-python` with green gates.

---

### Slice 0 - Infrastructure (pre–Band 4 commits)

Not a language slice, but required context:

- `53bbc7706` - parser regen for `grammar2jac --check`
- `e573b5857` - VM opcode fixtures for closure opcodes
- `7e94a5b78` (`checkpoint`) - thin-function codegen landed here with parser/tokenizer fixes

---

### Slice 1 - Thin functions **CLOSED** (`7e94a5b78` / checkpoint)

**Gate fixture**

```python
def f(x):
    return x + 1

result = f(2)  # → 3
```

**What was added**

- `visit_function_def`, `compile_function_cfg`, `visit_lambda` (stub path later)
- `emit_make_function_with_closure` (no defaults/closures yet)
- `fast_varnames_from_sym`, `emit_function_prologue` (RESUME only at first)
- Fast-local opcodes in `emit_name_load` / `emit_name_store`
- Module scope: `MAKE_FUNCTION` + `STORE_NAME`; nested: `STORE_FAST`

**Parser / tokenizer learnings (do not re-debug)**

1. `pa_empty_arguments()` must include all `arguments` fields (`vararg`, `kwarg`, …) - empty list defaults are not enough if fields are missing.
2. `rule_params` must try the **valid** parameter grammar before error recovery rules.
3. `FunctionDef` optional fields (`decorator_list`, `returns`, …) must normalize to `None` or `[]`, not absent.
4. **Tokenizer**: blank lines between statements in exec mode must consume the newline or the PEG parser loops forever on `def …\n\nresult = …`.

**Oracle checks**

- Nested `co_code`, `argcount == 1`, `varnames == ["x"]`, `flags == 3`

**Do not redo**

- Basic `def` / `return` lowering scaffolding
- `sym_visit_params` parameter registration via `add_def(..., DEF_PARAM, …)`

---

### Slice 2 - Recursion **CLOSED** (`20b16bfb4`)

**Gate fixture**

```python
def fact(n):
    if n <= 1:
        return 1
    return n * fact(n - 1)

result = fact(5)  # → 120
```

**Fixes bundled (not optional - recursion breaks without all of them)**

| Issue | Fix |
|-------|-----|
| Self-call compiled as closure load | Symtable: module locals excluded from `newbound` (§2.7) |
| Dead epilogue after `return` in if | `visit_if` propagates `terminated` from if-body |
| Extra `TO_BOOL` in if test | `visit_test_expr` bool-context compare for single `Compare` |
| Wrong NULL handling on recursive call | `LOAD_GLOBAL` `(idx << 1) \| 1` at call sites |

**Symtable test**

- `compiler_symtable.jac`: `"recursive function self-call matches oracle"`

**Do not redo**

- Global self-reference model for module-level functions
- If/return termination propagation

---

### Slice 3 - Lambdas **CLOSED** (`20b16bfb4`)

**Gate fixtures**

```python
f = lambda x: x + 1
result = f(2)

result = (lambda x: x + 1)(2)  # optional inline
```

**What was added**

- `compile_lambda_cfg` - shares `compile_function_cfg` metadata path
- `visit_lambda` in expr lowering → nested `<lambda>` PyCode + `MAKE_FUNCTION`
- Symtable: lambda body scope as function block

**Oracle checks**

- Nested code name `"<lambda>"`, same metadata as thin `def`

**Do not redo**

- Lambda as expression-value lowering (already distinct from `visit_function_def`)

---

### Slice 4 - Closures **CLOSED** (`20b16bfb4`)

**Gate fixtures**

```python
def outer(x):
    def inner():
        return x
    return inner()

result = outer(42)

# optional lambda capture
def outer(x):
    return lambda: x
result = outer(7)()
```

**What was added**

- `emit_function_prologue`: `MAKE_CELL`, `COPY_FREE_VARS`
- `emit_make_function_with_closure`: closure tuple + `SET_FUNCTION_ATTRIBUTE 8`
- `emit_name_load` / `emit_name_store`: `LOAD_DEREF` / `STORE_DEREF` via `localsplus_index`
- `u.cellvars` / `u.freevars` from symtable on nested code object
- Outer code object gets `cellvars`; inner gets `freevars`

**Oracle checks**

- Inner `co_code`, `freevars`, outer `cellvars`, `stacksize`

**Do not redo**

- VM closure calling convention (already in `pyc_first.jac`)
- Opcode fixtures for closure opcodes (`e573b5857`)

---

### Slice 5 - Default arguments **CLOSED** (`0ce9ade44`)

**Gate fixtures**

```python
def f(x, y=10):
    return x + y

result = f(2)       # → 12
result = f(2, 3)    # → 5

g = lambda x, y=1: x + y
result = g(2)       # → 3
```

**What was added**

- `emit_function_defaults` - fold constant defaults to `LOAD_CONST` tuple when possible; else evaluate in **enclosing** scope + `BUILD_TUPLE`
- `SET_FUNCTION_ATTRIBUTE 1` for defaults
- `sym_visit_arg_defaults` for symtable (positional defaults in enclosing scope)
- Parser/grammar fixes for `names_with_default` / lambda defaults (`parser_actions.jac`, `grammar2jac.py`, regen `parser.jac`)
- `layer_vm_conformance`: `SET_FUNCTION_ATTRIBUTE attaches defaults`

**Oracle checks**

- Full nested `co_code` parity including default tuple construction order

**Do not redo**

- Default expression scope rules (enclosing, not function body)
- Constant-folding path for literal defaults

---

### Slice 6 - `*args` / `**kwargs` / kw-only **CLOSED** (`9b29c1976`)

**Gate fixtures**

```python
def f(a, *args):
    return a + len(args)
result = f(1, 2, 3)  # → 3

def f(a, **kwargs):
    return a + len(kwargs)
result = f(1, b=2, c=3)  # → 3

def f(a, *, b=10):
    return a + b
result = f(2)  # → 12

def f(a, *args, b=1):
    return a + len(args) + b
result = f(1, 2, 3)  # → 4
```

**What was added**

- `function_argcounts` - always returns `(posonly+regular, posonly, kwonly)`; no longer rejects vararg/kwarg/kw-only
- `function_code_flags` - sets `CO_VARARGS` / `CO_VARKEYWORDS`
- `emit_function_kwdefaults` + `SET_FUNCTION_ATTRIBUTE 2`
- **Symtable param order fix**: kw-only params registered **before** `*vararg` (§2.6) - was wrong in earlier slices and broke combined signatures

**Oracle checks**

- `flags & CO_VARARGS`, `varnames` order e.g. `["a", "args"]` or `["a", "b"]` for kw-only
- `kwonlyargcount` on kw-only fixtures

**Do not redo**

- VM varargs/kwarg binding (`exec_code_frame` already correct)
- Rejecting vararg in `function_argcounts` - removed intentionally

---

### Slice 7 - Decorators **CLOSED** (`95db02261`)

**Gate fixtures**

```python
def deco(fn):
    return fn

@deco
def f(x):
    return x + 1

result = f(2)  # → 3
```

Multiple decorators: `@d1` `@d2` on same `def f`.

**What was added**

- `pa_function_def_decorators` attaches `decorator_list` to `FunctionDef` / `AsyncFunctionDef`
- `visit_function_def`: evaluate decorators, `MAKE_FUNCTION`, bottom-up `CALL 0` chain (CPython 3.14 self_or_null slot)
- Symtable: `sym_visit_load_expr` on each decorator in enclosing scope before function block
- `PyCode.tp_hashkey` - distinct nested code objects in const pool (was collapsing all codes to `""`)
- `nested_code_by_name` test helper when module has multiple nested PyCodes

**Oracle checks**

- Module `co_code` + nested `f` `co_code`, `stacksize`, `argcount`, `varnames`
- Symtable oracle for decorator reference in enclosing scope

**Do not redo**

- `CALL 0` for decorator application (function object is self_or_null, not a counted arg)
- Const dedup for `PyCode` must include name/qualname/co_code bytes

---

### Slice 8 - Keyword calls / `CALL_KW` **CLOSED** (`89320d8e6`)

**Gate fixtures**

```python
def f(a, **kwargs):
    return a + len(kwargs)

result = f(1, b=2, c=3)  # → 3; call site uses CALL_KW
```

Method call path (enables Band 5 class-method fixtures in the same commit):

```python
class C:
    def m(self):
        return 1

result = C().m()  # → 1; LOAD_ATTR (idx << 1) | 1 + CALL
```

**What was added**

- `call_effective_args` / `call_effective_keywords` - normalize `Call` args/kws
- `emit_call_keyword_values` - push kw values, then names tuple (`LOAD_CONST`)
- `emit_call_instruction` - `OP_CALL_KW` when kws present, else `OP_CALL`
- Wired through `visit_expr`, `compile_eval`, `visit_comp_elt`, and `visit_stmt` call paths
- Attribute callee lowering: `visit_expr` on `Call` with `Attribute` func → `LOAD_ATTR` `(idx << 1) | 1` (no `PUSH_NULL`)
- Rejects `**kwargs` unpacking at call sites (`keyword.arg is None`) with `NotImplementedError`
- `compiler_slice`: `band4 varkw parsed matches oracle co_code` (module + nested `f` parity with keyword call lowering)
- Same commit also landed Band 5 **scaffold** tests (`class C: pass`, `C().m()`) - partial class codegen only; not Band 5 completion

**Oracle checks**

- Module `co_code` + nested `f` `co_code` for `f(1, b=2, c=3)` - confirms `CALL_KW` emission at call site
- VM execution `result == 3`

**Do not redo**

- Keyword names tuple order (values pushed first, names tuple on top before `CALL_KW`)
- Attribute method calls without separate `PUSH_NULL` (NULL folded into `LOAD_ATTR`)

---

## Band 5 next

Full class band - **not** Band 4. Commit `89320d8e6` adds partial scaffolding (empty class, simple method call via `LOAD_ATTR` + `CALL`) so keyword-call work could be exercised end-to-end; that is not Band 5 done.

Band 5 scope (separate slices/commits):

- Imports (`import` / `from … import`)
- Name mangling (`__private`, `__dunder__` class scope rules)
- Metaclass / class keywords / multiple bases with keywords
- Nested classes, `__slots__`, deeper class forms

Treat any class bytecode in `89320d8e6` as forward-looking partial codegen, not a closed Band 5 slice.

## 4. Commit / PR discipline

| Rule | Detail |
|------|--------|
| One slice per commit | Message: `feat(jac-py): band-4 <slice name>` |
| Split track | `jac-py/bootstrap` = through Band 3 only; Band 4 stacks after |
| Release note | `release_notes/unreleased/jaclang/<PR#>.feature.md` when opening PR |
| Local gates | `compiler_slice`, `layer9`, `grammar2jac --check`; push to CI when possible |

---

## 5. Common failure modes (symptom → look here first)

| Symptom | First check |
|---------|-------------|
| Oracle `co_code` mismatch on function with defaults + closure | §2.5 stack / SET_FUNCTION_ATTRIBUTE order |
| `varnames` order wrong with `*args` + kw-only | §2.6 sym_visit_params order |
| Recursive top-level function uses `LOAD_DEREF` | §2.7 symtable `newbound` |
| Spurious `RETURN None` after `if`/`return` | `visit_if` `terminated` |
| Parser hang after `def` | tokenizer blank lines |
| `grammar2jac --check` drift | regen, fix translator not generated file |
| VM passes but native compile fails | you're testing host oracle path only - add `compile_parsed_exec` test |

---

## 6. Quick reference - key functions

```text
compiler_codegen.jac
  visit_function_def          # def lowering entry
  compile_function_cfg        # nested unverified_cfg for def body
  compile_lambda_cfg          # nested unverified_cfg for lambda body
  emit_function_prologue      # MAKE_CELL, COPY_FREE_VARS, RESUME
  emit_make_function_with_closure
  emit_function_defaults
  emit_function_kwdefaults
  function_argcounts
  function_code_flags
  fast_varnames_from_sym
  emit_name_load / emit_name_store
  call_effective_args / call_effective_keywords
  emit_call_keyword_values
  emit_call_instruction

compiler_symtable.jac
  sym_visit_params            # DEF_PARAM + varnames order
  sym_visit_arg_defaults      # default exprs in enclosing scope
  sym_analyze_block           # bound / cell / free propagation
  build_module_symtable       # entry
```
