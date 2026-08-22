# Band 11 annotated assignment / type alias oracle dump - completion summary

## Deliverables

- `dump.py`
  - Standalone CPython 3.14.7 host compiler dumper (run with plain system
    `python3`; the system interpreter IS 3.14.7).
  - Recursively walks nested `CodeType` values in `co_consts`, starting from
    the **root module code object** (unlike Band 6/7 which listed only
    descendants - here the module scope is where PEP 649 puts the annotation
    bytes).
  - Emits flags, bytecode hex, exception tables, locals/cells/freevars,
    `co_consts` summaries, complete instruction records, decoded exception
    entries.
  - Sanitizes `<code object X at 0x...>` memory addresses in `argrepr` to
    `at 0xADDR` - required for run-to-run determinism.
  - Emits all four data files (`goldens.json`, `goldens.md`,
    `paste_ready.json`, `INDEX.md`) so regeneration is one command.
- Verified deterministic: two consecutive runs produced identical md5 for all
  four outputs (`goldens.json` `507e1dccda96794798b3d89c58343ad0`,
  `goldens.md` `5cd3df7a916b961a20a1dbbb29fe80ef`).

## Fixtures and concrete results

| Fixture | Code objects | Result |
|---|---:|---|
| `module_annotated_with_value` | 2 | module + nested `__annotate__`; value store inline |
| `module_bare_annotation` | 2 | module + identical-shaped `__annotate__`; no inline store |
| `class_body_annotations` | 3 | class body emits `__annotate_func__` closed over `__classdict__` |
| `function_local_annotated` | 2 | annotation dropped; only `LOAD_SMALL_INT 3; STORE_FAST q` |
| `function_local_bare_annotation` | 2 | nothing at all; 6-byte body `RESUME; LOAD_CONST None; RETURN_VALUE` |
| `annotated_attribute_target` | 2 | legal; compiles to plain `STORE_ATTR k` |
| `annotated_subscript_target` | 2 | legal; compiles to plain `STORE_SUBSCR` |
| `type_alias_simple` | 2 | value function + `CALL_INTRINSIC_1 INTRINSIC_TYPEALIAS` |
| `type_alias_parametrized` | 3 | extra `<generic parameters of Box>` scope with `INTRINSIC_TYPEVAR` |
| `plain_assign_control` | 1 | bare `LOAD_SMALL_INT 5; STORE_NAME x` |

## Key PEP 649 / PEP 695 findings (CPython 3.14.7, quoted from dumps)

### Module scope: annotations are deferred, never inline

Module-level AnnAssign does NOT evaluate or store the annotation expression in
the module code object. Instead:

- The whole annotation expression is compiled into a separate code object
  named `__annotate__` that lives in `co_consts`:
  `consts=['5', '<code object __annotate__>', 'None']`.
- The module stores it under the name `__annotate__`
  (`MAKE_FUNCTION; STORE_NAME __annotate__`).
- The value part of `x: int = 5` stays inline in the module body:
  `LOAD_SMALL_INT 5; STORE_NAME x`. A bare `x: list` has NO inline store.
- Each annotated name is registered by adding its compile-time index to a
  set named `__conditional_annotations__`: `BUILD_SET 0;
  STORE_NAME __conditional_annotations__` up front, then per annotation
  `LOAD_NAME __conditional_annotations__; LOAD_SMALL_INT <idx>; SET_ADD 1;
  POP_TOP`. The index is the position of the name in the *annotation dict
  construction order* (0-based across all AnnAssigns in the scope), not a
  co_varnames index.
- `__conditional_annotations__` is a **cellvar of the module** and a freevar
  of `__annotate__` via `LOAD_GLOBAL` on it.

The `__annotate__` prologue (identical in every deferred-annotation code
object on this build) is a lazy-format version guard:

```text
LOAD_FAST_BORROW 0 (.format / format)
LOAD_SMALL_INT   2
COMPARE_OP      132 (>)
POP_JUMP_IF_FALSE -> L1
NOT_TAKEN
LOAD_COMMON_CONSTANT 1 (NotImplementedError)
RAISE_VARARGS    1
```

i.e. "if requested format > 1, raise NotImplementedError" (format 0 = values,
1 = strings). Then it builds the dict eagerly: `BUILD_MAP 0`, and per entry
`LOAD_GLOBAL <annotation expr names>... ; COPY 2; LOAD_CONST '<name>';
STORE_SUBSCR; RETURN_VALUE`.

### Class scope: same deferral, different plumbing

Class bodies emit an `__annotate__` code object too, but stored as
`__annotate_func__` in the class namespace, closed over `__classdict__`:

```text
LOAD_FAST_BORROW 0 (__classdict__)
BUILD_TUPLE      1
LOAD_CONST       2 (<code object __annotate__>)
MAKE_FUNCTION
SET_FUNCTION_ATTRIBUTE 8 (closure)
STORE_NAME       5 (__annotate_func__)
```

Inside class-body `__annotate__`, entries write through the cell instead of a
fresh map: `LOAD_DEREF 1 (__classdict__); LOAD_FROM_DICT_OR_GLOBALS <expr>;
COPY 2; LOAD_CONST 'y'; STORE_SUBSCR`. The class body itself still executes
value assignments inline (`LOAD_CONST 'a'; STORE_NAME y`); bare `z: dict`
emits nothing inline. Other 3.14 class-body machinery observed:
`__firstlineno__` (set to the class def line via `LOAD_SMALL_INT 1`),
`__static_attributes__` tuple, `__classdictcell__`.

### Function scope: annotations vanish entirely

Function-local annotations produce zero annotation machinery. With a value,
only the assignment remains (`q: int = 3` -> `LOAD_SMALL_INT 3;
STORE_FAST q`, 10-byte body). Bare (`q: list`) compiles to a 6-byte body:
`RESUME 0; LOAD_CONST None; RETURN_VALUE` - the statement contributes no
bytes at all. Attribute/subscript annotated targets inside functions are also
pure assignment semantics: `o.k: int = 1` -> `LOAD_SMALL_INT 1;
LOAD_FAST_BORROW o; STORE_ATTR k`; `d["k"]: int = 1` -> `... LOAD_CONST 'k';
STORE_SUBSCR`. Both are legal (compile cleanly).

### Type aliases (PEP 695)

Simple `type Pair = tuple[int, int]`:

- Value function `Pair` in co_consts with a defaults tuple:
  `consts=["'Pair'", 'None', '(1,)', '<code object Pair>']`;
  module does `LOAD_CONST 'Pair'; LOAD_CONST None; LOAD_CONST (1,);
  LOAD_CONST <Pair>; MAKE_FUNCTION; SET_FUNCTION_ATTRIBUTE 1 (defaults);
  BUILD_TUPLE 3; CALL_INTRINSIC_1 11 (INTRINSIC_TYPEALIAS); STORE_NAME Pair`.
- The value function has the same format-guard prologue, then computes the
  RHS lazily: `LOAD_GLOBAL tuple/int/int; BUILD_TUPLE 2; BINARY_OP 26 ([])`.

Parametrized `type Box[T] = list[T]`:

- The module calls a synthetic scope named `<generic parameters of Box>`
  (`MAKE_FUNCTION; PUSH_NULL; CALL 0; STORE_NAME Box`) whose body creates the
  TypeVar and constructs the alias: `INTRINSIC_TYPEVAR` (intrinsic 7),
  `STORE_DEREF T`, then builds `(alias_name, params_tuple, defaults)` and
  `CALL_INTRINSIC_1 11 (INTRINSIC_TYPEALIAS)`.
- The alias value function `Box` becomes a **closure over T**
  (`freevars=('T',)`, `COPY_FREE_VARS 1`) and carries `CO_NESTED`:
  flags `0x13` (OPTIMIZED|NEWLOCALS|NESTED) vs `0x3` everywhere else.

### Flags summary

| Scope | co_flags | Named bits |
|---|---|---|
| module (any fixture) | `0x0` | none |
| `__annotate__` (module) | `0x3` | OPTIMIZED, NEWLOCALS |
| class body | `0x0` | none |
| `__annotate__` (class) | `0x3` | OPTIMIZED, NEWLOCALS |
| plain function | `0x3` | OPTIMIZED, NEWLOCALS |
| simple type-alias value fn | `0x3` | OPTIMIZED, NEWLOCALS |
| parametrized type-alias value fn | `0x13` | OPTIMIZED, NEWLOCALS, NESTED |
| generic-parameters scope | `0x3` | OPTIMIZED, NEWLOCALS |

No exception tables anywhere in this stream (no try/with/loops in fixtures).

### New opcodes/intrinsics the Jac implementer needs

- `LOAD_SMALL_INT` (small-int fast path replaces many `LOAD_CONST`)
- `LOAD_FAST_BORROW`, `LOAD_COMMON_CONSTANT`, `MAKE_CELL`,
  `SET_FUNCTION_ATTRIBUTE` (arg 8 closure / arg 1 defaults),
  `CALL_INTRINSIC_1` args 11 (`INTRINSIC_TYPEALIAS`) and
  7 (`INTRINSIC_TYPEVAR`), `LOAD_FROM_DICT_OR_GLOBALS`, `LOAD_LOCALS`,
  `STORE_DEREF`/`COPY_FREE_VARS`, `BUILD_SET`/`SET_ADD`,
  `COMPARE_OP 132 (>`)`,`BINARY_OP 26 ([])`.

## Validation

- `dump.py` ran successfully and generated all 10 fixtures; JSON parses.
- Determinism verified by double-run md5 comparison after fixing the
  address-in-`argrepr` instability (see Deliverables).
- No Jac runtime, compiler loop, or repository file was used or modified.
