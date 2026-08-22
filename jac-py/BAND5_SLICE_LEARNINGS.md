# Band 5 slice learnings (JacPython native compiler)

**Read this before touching Band 6 exception work.** Band 5 landed in commit `ff4014135`
(one commit; logical slices below). Do not re-derive facts already captured here -
verify against oracle fixtures and extend the patterns below.

Last updated: 2026-08-17 (`jac-python` through `ff4014135`).

---

## 1. Two-axis maturity (still applies)

| Axis | Status on Band 5 HEAD |
|------|------------------------|
| **VM/runtime** | Broad: classes, imports, MRO, descriptors already work when fed **host-compiled** PyCode |
| **Native compiler** | Band 5 closed for core class/import/mangling; partial scaffold from Band 4 slice 8 (`C().m()`) is superseded |

A slice is “done” when **native source → native compile → JacPython VM** matches CPython
oracle on the slice fixture.

---

## 2. Global invariants (Band 5 + carry-forward from Band 4)

### 2.1 Pipeline and test pattern

Same as Band 4 §2.1–2.2. Each slice adds **paired** tests in:

1. `jac-py/jacpython/compiler_slice.jac` - `compile_parsed_exec`
2. `jac-py/jacpython/layer9_product_exec.jac` - `product_exec`

Helpers: `nested_code_by_name`, `oracle_exec`, `assert_matches_oracle`, `compile_parsed_exec`.

For Band 5+, also assert `exceptiontable` when non-empty (Band 6+).

### 2.2 Files by concern

| Concern | Primary files |
|---------|----------------|
| Class/import codegen | `compiler_codegen.jac` (`visit_class_def`, `compile_class_cfg`, `visit_import*`) |
| Name mangling | `compiler_symtable.jac` (`mangle_name`), `compiler_codegen.jac` (`codegen_mangle`) |
| Class scope symtable | `compiler_symtable.jac` (`sym_visit_stmt` ClassDef branch, `can_see_class_scope`) |
| Exception regions (comprehensions) | `compiler_ir.jac` (`except_region`), `assembler.jac` (`assemble_exception_table`) |
| VM opcode registry | `jac-py/tools/vm_opcode_fixtures.py`, `layer_vm_conformance.jac` |

### 2.3 CPython 3.14 class creation stack (critical)

Outer `class C(...):` lowering (`visit_class_def`):

```text
  LOAD_BUILD_CLASS
  PUSH_NULL
  LOAD_CONST <nested PyCode>
  MAKE_FUNCTION
  LOAD_CONST "C"          # class name
  <evaluate bases...>
  CALL / CALL_KW          # 2 + nargs bases (+ kw count if keywords)
  STORE_NAME / STORE_FAST
```

`emit_class_build_call` pushes base expressions left-to-right, then:

- No keywords: `CALL` with oparg `2 + len(bases)` (func + NULL + bases)
- With keywords: evaluate kw values, `LOAD_CONST` names tuple, `CALL_KW`

Keyword unpacking (`**kwargs` in class header) → `NotImplementedError`.

### 2.4 Class body nested PyCode (critical)

`compile_class_cfg` builds a separate code object:

| Field | Rule |
|-------|------|
| `name` | class name (`"C"`) |
| `qualname` | `"C"` at module scope; `"Outer.Inner"` for nested (`sym_class_qualname`) |
| `flags` | `CO_NESTED` when `sym_cls.nested` |
| `cellvars` | `["__classdict__"]` when `class_body_has_function(cd)` |
| `argcount` | 0 (class bodies are not callable with args) |

**Prologue** (`emit_class_body_prologue`):

1. `MAKE_CELL` per `cellvars` (only `__classdict__` today)
2. `RESUME`
3. `LOAD_NAME __name__` → `STORE_NAME __module__`
4. `LOAD_CONST qualname` → `STORE_NAME __qualname__`
5. `LOAD_SMALL_INT` / folded int `__firstlineno__` → `STORE_NAME __firstlineno__`
6. If cellvars: `LOAD_LOCALS` → `STORE_DEREF __classdict__`

**Epilogue** (`emit_class_body_epilogue`):

1. `LOAD_CONST ()` → `STORE_NAME __static_attributes__`
2. If cellvars: `LOAD_FAST_BORROW __classdict__` → `STORE_NAME __classdictcell__`
3. `LOAD_CONST None` → `RETURN_VALUE`

Body statements use `visit_stmt` with `g.private` set to class name (mangling).

### 2.5 `__classdict__` cell (do not skip)

When a class body contains **any** `def` or `async def`, CPython emits `cellvars=["__classdict__"]`
and the prologue/epilogue boilerplate above. Method-only classes without this cell produce
**different** nested `co_code` - oracle tests pin `BAND5_CLASS_C_CO_CODE` for the canonical shape.

### 2.6 Nested class storage

| Enclosing scope | Bind class name via |
|-----------------|---------------------|
| Module | `STORE_NAME` |
| Function | `STORE_FAST` (nested class is a fast local) |

Nested class PyCode gets `CO_NESTED` and qualname `Outer.Inner`.

### 2.7 Import lowering (critical)

**`import foo` / `import foo.bar`:**

```text
  LOAD_SMALL_INT 0        # level (absolute import)
  LOAD_CONST None         # fromlist
  IMPORT_NAME "foo"       # name table uses first component only for dotted
  STORE_NAME foo          # bind first component (import_bind_name)
```

**`from mod import a, b as c`:**

```text
  LOAD_SMALL_INT level
  LOAD_CONST ('a', 'b')   # fromlist tuple of imported names
  IMPORT_NAME "mod"
  IMPORT_FROM "a" ; STORE_NAME ...
  IMPORT_FROM "b" ; STORE_NAME c   # asname via import_bind_name
  POP_TOP
```

`ensure_import_prefix_consts`: CPython keeps int `0` in `co_consts` for import prefix
(dead-small-int slot) even though level uses `LOAD_SMALL_INT`.

Symtable: each bound alias is `DEF_LOCAL` via `sym_import_bind_name`.

### 2.8 Name mangling (critical)

Rules in `mangle_name(private, name)`:

- No `private` context → unchanged
- Not starting with `__` (or single `_`) → unchanged
- `___dunder___` (len > 2 and `[2] == '_'`) → unchanged
- Otherwise → `"_" + private + name` (e.g. `__x` in class `C` → `_C__x`)

Applied in:

- Symtable: `add_def` / `add_use` while `b.private = cd.name`
- Codegen: `codegen_mangle(g, name)` on all name loads/stores/attrs **inside** class body
  (`g.private` threaded through `new_cfg_builder` in `compile_class_cfg`)

Methods referencing `self.__x` compile to `LOAD_ATTR _C__x`.

### 2.9 Method calls (from Band 4 slice 8 - do not redo)

`C().m()` uses `LOAD_ATTR (idx << 1) | 1` + `CALL` (NULL folded into attr load).
Class band tests depend on this; it is not Band 5 codegen.

### 2.10 VM fixtures added in Band 5

| Opcode | Fixture type | Notes |
|--------|--------------|-------|
| `IMPORT_NAME` | CPython | `import os` |
| `IMPORT_FROM` | CPython | `from os import path` |
| `LOAD_BUILD_CLASS` | CPython | empty class |
| `CALL_KW` | CPython | keyword call (also Band 4) |
| `LOAD_LOCALS` | **compiler-only** | class body with method; Jac VM class-body execution not host-parity for this shape |

After new opcode emission: update `vm_opcode_fixtures.py` + `layer_vm_conformance.jac` markers.

---

## 3. Slice catalog

Status key: **CLOSED** = green gates on `jac-python` HEAD.

---

### Slice 1 - Empty class and methods **CLOSED** (`ff4014135`)

**Gate fixtures**

```python
class C:
    pass
result = C.__name__  # → "C"

class C:
    def m(self):
        return 1
result = C().m()  # → 1
```

**Oracle checks**

- Module `co_code`, nested `C` `co_code`, `stacksize`
- Method nested code: `argcount == 1`, `varnames == ["self"]`, `cellvars == ["__classdict__"]`
- Pinned class body bytes: `BAND5_CLASS_C_CO_CODE` in test files

**Do not redo**

- `LOAD_BUILD_CLASS` / `MAKE_FUNCTION` / class prologue-epilogue scaffolding
- `compile_class_cfg` entry point

---

### Slice 2 - Imports **CLOSED** (`ff4014135`)

**Gate fixtures**

```python
import math
from operator import add
from operator import add as plus
```

Execution fixtures: `math.pi > 3`, `add(1, 2) == 3`.

**Oracle checks**

- Module `co_code`, `stacksize`, `names`

**Do not redo**

- `emit_import_name_call` / `visit_import` / `visit_import_from`
- `import_bind_name` / `ensure_import_prefix_consts`

---

### Slice 3 - Name mangling **CLOSED** (`ff4014135`)

**Gate fixture**

```python
class C:
    __x = 1
    def m(self):
        return self.__x
result = C().m()  # → 1
```

**Oracle checks**

- Module + nested `C` + method `m` `co_code` parity
- Mangled names in `co_names` (e.g. `_C__x`)

**Do not redo**

- `mangle_name` / `codegen_mangle` / symtable `private` push in class block

---

### Slice 4 - Inheritance **CLOSED** (`ff4014135`)

**Gate fixture**

```python
class Base:
    x = 1
class C(Base):
    pass
result = C().x  # → 1
```

**What was added**

- Base expressions evaluated and passed to `emit_class_build_call`
- `CALL` with `2 + len(bases)` when no keywords

**Do not redo**

- Single-base inheritance lowering

---

### Slice 5 - Nested classes **CLOSED** (`ff4014135`)

**Gate fixture**

```python
class Outer:
    class Inner:
        x = 1
result = Outer.Inner.x  # → 1
```

**Oracle checks**

- Nested `Outer` + `Inner` `co_code`
- `Inner.qualname == "Outer.Inner"`

**Do not redo**

- `sym_class_qualname` / `CO_NESTED` / `STORE_FAST` for function-enclosed classes

---

## Band 6 next

Exception, `with`, assertion lowering - **not started** in native codegen.

`visit_stmt` returns `NotImplementedError` for `Try`, `With`, `Assert`.

Existing infrastructure to reuse (do not reimplement):

- `except_region` + `assemble_exception_table` (comprehensions already use this)
- `emit_deferred_comp_handlers` + `OP_RERAISE` pattern
- VM exception semantics proven via **host-compiled** bytecode in `layer_vm_conformance.jac`

Band 6 scope (separate slices/commits):

1. `try` / `except` typed handler
2. bare `except`, `raise`, exception binding `as`
3. `try` / `finally`
4. `with` (context manager)
5. `assert`

Each slice: oracle `co_code` + `exceptiontable`, VM execution, VM opcode fixtures for new emissions.

### Band 5 deferrals (not blockers for Band 6)

- Metaclass / `class C(metaclass=Meta)` oracle fixtures
- `__slots__`
- Relative imports (`level > 0`)
- Multiple inheritance edge cases
- Class decorators (`@deco` on `class`) - parser supports; codegen not wired

---

## 4. Commit / PR discipline

| Rule | Detail |
|------|--------|
| One slice per commit | Message: `feat(jac-py): band-6 <slice name>` |
| Release note | `release_notes/unreleased/jaclang/<PR#>.feature.md` when opening PR |
| Local gates | `compiler_slice`, `layer9`, `layer_vm_conformance`, `grammar2jac --check`, `vm_opcode_fixtures.py --check` |

---

## 5. Common failure modes (symptom → look here first)

| Symptom | First check |
|---------|-------------|
| Class nested `co_code` mismatch | §2.4 prologue/epilogue; §2.5 `__classdict__` cell |
| `LOAD_LOCALS` in class body oracle fail | Expected when methods present; check `cellvars` |
| Import `co_consts` order wrong | §2.7 `ensure_import_prefix_consts` dead int 0 |
| `self.__x` loads wrong name | §2.8 mangling; `g.private` in `compile_class_cfg` |
| Nested class `qualname` wrong | §2.6 `sym_class_qualname` + enclosing `g.private` |
| `C(Base)` call arity wrong | §2.3 `CALL 2 + len(bases)` |
| VM passes but native compile fails | Add `compile_parsed_exec` test, not just `product_exec` |
| Method call fails on native class | Band 4 slice 8 `LOAD_ATTR` NULL fold - §2.9 |

---

## 6. Quick reference - key functions

```text
compiler_codegen.jac
  visit_class_def           # class stmt at module/function scope
  compile_class_cfg         # nested class body PyCode
  emit_class_body_prologue / emit_class_body_epilogue
  emit_class_build_call     # bases + CALL/CALL_KW
  class_body_has_function
  sym_class_qualname
  codegen_mangle            # class-body name table
  visit_import / visit_import_from
  emit_import_name_call
  import_bind_name
  ensure_import_prefix_consts

compiler_symtable.jac
  mangle_name               # __private → _Class__private
  sym_import_bind_name      # asname / first dotted component
  sym_visit_stmt (ClassDef) # push class block, set b.private

compiler_ir.jac / assembler.jac
  except_region             # start/end/handler blocks + stack_depth
  assemble_exception_table  # varint encoding for co_exceptiontable
```
