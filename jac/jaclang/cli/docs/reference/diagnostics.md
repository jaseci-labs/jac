# Errors and Warnings

The Jac compiler uses a structured diagnostic code system. Every error, warning, and note has a unique code that identifies the issue and can be used for inline suppression.

## Code Format

Diagnostic codes follow the pattern `{severity}{category}{sequence}`:

- **Severity**: `E` (error) or `W` (warning)
- **Category digit**: `0` = syntax, `1` = type, `2` = semantic, `3` = lint, `4` = import, `5` = codegen, `7` = dev loop / client runtime, `9` = internal
- **Sequence**: Three-digit number within the category

For example, `E1030` is a **type error** about attribute access, and `W3005` is a **lint warning** about empty parentheses.

## Guide Pointers

When a diagnostic maps to a topic covered by the bundled reference guides, `jac check` prints a one-line pointer beneath it:

```text
error[E1001]: Cannot assign Literal["hello"] to int
  --> example.jac:2:5
  → run 'jac guide jac-types' for guidance
```

Run the suggested command for the relevant reference material. See [`jac guide`](cli/index.md#jac-guide).

## Suppressing Diagnostics

### Inline Suppression

Add a `# jac:ignore[CODE]` comment on the same line as the diagnostic to suppress it:

<!-- jac-skip -->
```jac
x = some_func();  # jac:ignore[E1030]
```

Multiple codes can be suppressed on the same line:

<!-- jac-skip -->
```jac
x = some_func();  # jac:ignore[E1030,W2001]
```

### Project-Level Suppression

Use `jac.toml` to suppress diagnostics project-wide. See the [Configuration](config/index.md#checklint) reference for lint rule configuration.

### CLI Flags

- `--nowarn` on `jac check` suppresses all warnings (errors are still shown)
- `-e` / `--diagnostics` on `jac run` controls diagnostic verbosity: `error` (default -- report error-level diagnostics with full detail), `all` (errors + warnings), or `none` (silent). This flag governs *what is printed*, not whether the program runs. `jac run` still executes -- and exits `0` -- when the type checker finds errors: for example, `x: int = "no";` reports `E1001` under `jac check` but runs anyway under `jac run`. Only errors that stop the compiler from producing runnable code (parse/lex and codegen errors, such as a missing `;`) abort a run. To gate on type errors, use `jac check`, which exits non-zero

---

## Syntax Errors (E0xxx)

Emitted by the parser and lexer during source code parsing.

### Token Expectation

| Code | Message |
|------|---------|
| `E0001` | Expected '{expected}', got '{got}' |
| `E0002` | Missing '{token}' |
| `E0003` | Expected identifier, got '{got}' |
| `E0004` | Unexpected token in expression: '{got}' |
| `E0005` | Unexpected token '{token}' |
| `E0006` | Unexpected token |

### Keyword Restrictions

| Code | Message |
|------|---------|
| `E0010` | '{keyword}' is not supported in Jac |
| `E0012` | Use the `new(target, ...args)` ambient builtin to create new instances |
| `E0013` | '{keyword}' is a keyword and cannot be used as a {context} name |
| `E0014` | '{name}' is not a keyword -- remove the backtick |

### Operator / Expression Errors

| Code | Message |
|------|---------|
| `E0020` | Walrus operator ':=' requires a simple name on the left side |
| `E0021` | Expected `:<+` or `:+>` to close connect operator |
| `E0022` | Expected ':' or '{' after lambda parameters |
| `E0023` | Expected augmented assignment in for-loop step (for init while cond with step) |

### Statement-Level Errors

| Code | Message |
|------|---------|
| `E0030` | Unexpected semicolon at module level |
| `E0031` | Module-level 'with' blocks only support 'entry', not 'exit' |
| `E0032` | Unexpected '{token}' -- must follow its parent statement (if/try/match/switch) |
| `E0034` | Expected 'with' after 'can' ability name (use 'def' for function-style declarations) |

### Compile-Time Evaluation

Emitted at `comptime` sites; see [Compile-Time Evaluation](language/comptime.md) and `jac guide jac-comptime`.

| Code | Message |
|------|---------|
| `E0033` | {what} is not known at compile time{reason} |
| `E0108` | Compile-time evaluation failed: {reason} |
| `E0109` | Compile-time assertion failed{message} |

All three block code generation for the module that reports them.

### Block / Body Requirements

| Code | Message |
|------|---------|
| `E0040` | try statement requires at least one except or finally block |
| `E0041` | match statement requires at least one case |
| `E0042` | switch statement requires at least one case |
| `E0043` | enum body must contain at least one member |
| `E0044` | import statement must specify at least one item |
| `E0045` | Expected literal (INT, FLOAT, or STRING) as mapping pattern key |
| `E0046` | Unexpected token in archetype body |
| `E0047` | Expected '{' or 'by' for impl body |

### Removed Syntax

| Code | Message |
|------|---------|
| `E0048` | Parenthesized filter syntax `(?:...)` was removed. Use bracket syntax `[?:...]` instead. |
| `E0049` | `'root()'` was removed. Use bare `'root'` instead. |

### Parameter List Errors

| Code | Message |
|------|---------|
| `E0050` | Duplicate '{param}' in parameter list |
| `E0051` | '{first}' must appear before '{second}' in parameter list |
| `E0052` | Parameter '{name}' is missing a type annotation |

### Property Declaration Errors

| Code | Message |
|------|---------|
| `E0080` | Property declarations cannot have an initializer (declare backing storage as a separate `has` field) |
| `E0081` | Property declaration must contain at least one of `getter`, `setter`, `deleter` |

### Client Component Errors

| Code | Message |
|------|---------|
| `E0082` | Cannot assign to state field '{name}' during render (component body statements run on every render and state writes are immediately visible; move the assignment into a `can` ability, an event handler, or a method) |

### Parser Warnings

| Code | Message |
|------|---------|
| `W0060` | Docstrings in Jac go before the declaration, not inside the body |
| `W0063` | JSX spread `{...expr}` is JS-idiomatic. Prefer `{**expr}` in Jac. |

### Lexer Errors

| Code | Message |
|------|---------|
| `E0100` | Unterminated string literal |
| `E0101` | Unterminated block comment |
| `E0102` | Unterminated f-string |
| `E0103` | Unterminated inline Python block |
| `E0104` | Unexpected end of JSX content |
| `E0105` | Unexpected character: '{ch}' |
| `E0106` | Unexpected character in JSX tag: '{ch}' |
| `E0107` | Lexer stuck at EOF in mode {mode} |
| `E0110` | Unsupported escape sequence '\N{...}' |

---

## Type Errors (E1xxx)

Emitted by the type checker and type evaluator.

### Assignment / Return Mismatches

| Code | Message |
|------|---------|
| `E1001` | Cannot assign {actual} to {expected} |
| `E1002` | Cannot return {actual}, expected {expected} |
| `E1003` | Return type annotation required when function returns a value |
| `E1004` | Function '{name}' declared return type {ret_type} but may implicitly return None |

!!! tip "`E1001`/`E1002` with `any` on the right-hand side"
    A common trigger for `E1001` and `E1002` is Jac's strict gradual-typing rule: in `.jac` source, an `any` value cannot silently flow into a declared non-`any`, non-`object` destination. Ways to clear it -- type the source (e.g. `has reports: list[T]` on a walker, `.pyi` stub on a Python utility), drop the annotation (`x = src()` makes `x` inferred-`any`), annotate `any` explicitly (`x: any = src()`) and narrow before downstream use, or re-type at the use site with the [`as` cast](language/operators.md#10-the-as-cast-operator) (`src() as list[T]`) when you know more than the checker. See [The `any` Type and Gradual Typing](language/types-and-values.md#the-any-type-and-gradual-typing).

### Operator Errors

| Code | Message |
|------|---------|
| `E1010` | Operator "{op}" not supported for type "{type}" |
| `E1011` | Unsupported operand types for {op}: {left} and {right} |
| `E1110` | Operator "{op}" not supported between types "{left}" and "{right}" (comparison operators) |
| `E1124` | Membership test "{op}" over an operand with no static type ("{type}"); native code cannot answer it |
| `E1126` | Integer literal {value} does not fit in {type} (range {min}..{max}) |
| `E1127` | Cannot implicitly convert {src} to {dest}; the conversion is not value-preserving |
| `E1128` | Operands of '{op}' have no common fixed-width type ({left} and {right}) |
| `E1129` | Unary minus on unsigned type {type} |
| `E1130` | Float literal {value} overflows {type} (largest finite magnitude {max}) |

!!! tip "Fixing `E1126`-`E1130` (fixed-width numerics)"
    The ten sized types (`i8`..`u64`, `f32`, `f64`) convert implicitly only along the value-preserving lattice (widening, unsigned into a strictly wider signed type, exactly-representable ints into `f32`, any int-kind into `f64`, `f32 -> f64`). `int` and `float` are in that lattice rather than beside it: `int` is the signed 64-bit machine integer and behaves as `i64`, `float` is binary64 and behaves as `f64`, so `u64 -> int` needs the same cast `u64 -> i64` does. `E1126`: the literal is out of range -- use a wider type or spell the modular result with `T.wrap(x)`. `E1127`: cast at the boundary with the checked `T(x)` (raises `OverflowError` out of range) or widen the destination; extern `i32`/`u64` parameters need the cast from a plain `int`. `E1128`: neither operand widens into the other -- cast one side so the operation's width and sign are explicit. `E1129`: negate in a signed type (`-i64(x)`) or use `wrapping_neg(x)`. `E1130`: the literal is past what the target float can represent and would arrive as `inf` -- widen the type or write a value it can hold; precision loss inside the range is accepted. See `jac guide jac-types` and [Fixed-width semantics](language/types-and-values.md#fixed-width-semantics).

!!! tip "Fixing `E1124` (membership over an untyped operand)"
    `E1124` fires on natively lowered code when the container operand of an `in` / `not in` comparison has no static type at all -- typed `any`, or left unannotated and never inferred. Every container answers `in` from its own layout, and native code has no dynamic-dispatch tier to fall back on, so the operand must carry a static type by the time the comparison is reached. Annotate the operand with the container it actually holds (`list[Tag]`, `dict[str, int]`, `set[str]`), or bind it to a directly-typed local first, so its layout reaches the comparison. The error blocks codegen.

### Iterability / Callable

| Code | Message |
|------|---------|
| `E1020` | Cannot unpack non-iterable {type} |
| `E1021` | Type "{type}" is not iterable |
| `E1022` | Type {type} is not iterable (no \_\_iter\_\_ method) |
| `E1023` | Type "{type}" is not callable |

### Attribute Access

| Code | Message |
|------|---------|
| `E1030` | Type "{base_type}" has no attribute "{attr}" |
| `E1031` | Cannot access attribute "{attr}" for type "{type}" |
| `E1032` | Type is Unknown, cannot access attribute "{attr}" |
| `E1033` | Member "{member}" not found on type "{type}" |
| `E1034` | Cannot perform assignment comprehension on type "{type}" |
| `E1035` | Type "{src}" is not assignable to type "{dest}" |

### Subscript / Await

| Code | Message |
|------|---------|
| `E1040` | Type "{type}" is not subscriptable |
| `E1041` | Type "{type}" is not awaitable |
| `E1044` | Cast target is not a type: "{type}" |

### Function Call Errors

| Code | Message |
|------|---------|
| `E1050` | Not all required parameters were provided in the function call: {params} |
| `E1051` | Too many positional arguments |
| `E1052` | Named argument '{name}' does not match any parameter |
| `E1053` | Cannot assign {actual} to parameter '{name}' of type {expected} |
| `E1054` | No matching overload found for the function call with the given arguments |
| `E1055` | No matching overload found for method "{method}" with the given arguments |
| `E1056` | Positional only parameter '{name}' cannot be matched with a named argument |
| `E1057` | Parameter '{name}' already matched |

### TypeVar Errors

| Code | Message |
|------|---------|
| `E1060` | TypeVar "{name}" must be assigned to a simple variable |
| `E1061` | TypeVar name "{name}" must match the assigned variable name "{var}" |
| `E1062` | TypeVar "{name}" is already in use by an outer scope |
| `E1063` | TypeVar() requires a string literal as the first argument |
| `E1064` | TypeVar requires at least two constrained types |
| `E1065` | Type variable "{name}" has no meaning in this context |

### Callable Type Errors

| Code | Message |
|------|---------|
| `E1070` | Callable requires at least one type argument for return type |
| `E1071` | First argument to Callable must be a list of types or ellipsis |
| `E1072` | Callable requires a return type as second argument |
| `E1073` | Callable accepts only two type arguments: parameter types and return type |

### Variance Errors

| Code | Message |
|------|---------|
| `E1080` | Contravariant type variable cannot be used in return type |
| `E1081` | Covariant type variable cannot be used in parameter type |

### Exception / Context Manager / Yield

| Code | Message |
|------|---------|
| `E1090` | Cannot raise {type} (not an exception type) |
| `E1091` | Type {type} cannot be used in 'with' statement (no \_\_enter\_\_ method) |
| `E1092` | Type {type} cannot be used in 'with' statement (no \_\_exit\_\_ method) |
| `E1093` | Cannot yield {actual}, expected {expected} |
| `E1094` | Visit target must be a node type, got {type} |
| `E1095` | Field '{field}' declared 'postinit' is never assigned in {arch}.postinit |

### Connection Type Errors

| Code | Message |
|------|---------|
| `E1096` | Connection left operand must be a node instance |
| `E1097` | Connection right operand must be a node instance |
| `E1098` | Connection type must be an edge instance |
| `E1099` | Cannot access attribute "{attr}" for type "{type}"; attribute is missing from {missing} |

### mobUI-Project JSX Host Tags

Emitted by `JsxIntrinsicGuardPass` when a `mobui` project (see [React Native target](plugins/jac-client.md#react-native-target-beta)) uses a raw HTML host tag in JSX. The guard resolves every tag name in the enclosing scope; only **unresolved lowercase names** are treated as HTML host elements and rejected. Uppercase components and lowercase components that resolve to an in-scope symbol are allowed. `.jac` web-boundary files (but not `.native.jac` files, which target React Native) and modules outside the project root are exempt; the client kind is discovered from each module's own project `jac.toml`, never the process cwd.

| Code | Message |
|------|---------|
| `E1105` | JSX tag '<{tag}>' is not in scope in a mobUI project; use {suggestion} instead |

!!! tip "Fixing `E1105`"
    `E1105` fires only in `mobui` projects (`[project] client_kind = "mobui"` in `jac.toml`). Replace the HTML tag with the suggested `@jac/mobui` primitive: `div`/`section`/`main` -> `View`, `span`/`p`/`h1`-`h6` -> `Text`, `button` -> `Pressable`, `input`/`textarea` -> `TextInput`, `img` -> `Image`, `ul`/`ol` -> `ScrollView`. If the lowercase name is meant to be a component, import it so it resolves in scope. Web projects (`client_kind` unset) are unaffected -- HTML tags remain valid there.

### Ownership / Borrow Errors

Emitted by `OwnershipCheckPass` for `own`/`imm`/`borrow`/`&`/`&mut` bindings and `in <handle> { }` region opens. See [Ownership & Borrowing](language/ownership-borrowing.md). On the native pathway the checker is one of the required analyses: it always runs there, and error-severity findings block native codegen -- a clean check is what makes the annotations trustworthy facts for lowering (see the [Ownership Fact Schema](../internals/ownership-checker-spec.md)). Whether diagnostics are *displayed* never changes generated code; builds with and without display are bit-identical.

| Code | Message |
|------|---------|
| `E1301` | Use of '{name}' after it was moved |
| `E1302` | Conflicting mutable borrow of '{name}' while another borrow is live |
| `E1303` | Cannot mutate '{name}' while a shared borrow of it is live |
| `E1304` | '{name}' is destroyed while still borrowed |
| `E1305` | *Reserved, not yet registered* -- will be "Linear resource '{name}' is never consumed" once the planned `linear` marker lands (a `linear` binding must be moved exactly once; plain `own` is affine and may be silently dropped) |
| `E1306` | Borrow of '{name}' escapes its scope |
| `E1307` | Reference to '{name}' escapes its region |
| `E1308` | '{name}' is not sendable across a concurrency boundary |
| `E1309` | Cannot mutate '{name}' through a deep-immutable `imm` binding |
| `E1311` | Cannot freeze '{name}': the value may be aliased |
| `E1313` | `flow for` does not allow {name} |
| `E1314` | `partition(n)` does not allow {name} |

### Zero-RC Enforcement Errors

Emitted by `OwnershipCheckPass` only in **nogc-enforced** native modules (`jac nacompile --enforce-nogc`, or a module matching a `jac.toml [gc.enforce]` pattern -- see [Zero-RC ownership compilation](language/native-pathway.md#zero-rc-ownership-compilation)). They make zero-RC ownership coverage a compile-time contract: every heap-typed contract position must be in the owned world, and each violation is a hard error that blocks native codegen. The `{provenance}` in every message states why the module is enforced (the CLI flag or the matching config pattern).

| Code | Message |
|------|---------|
| `E1401` | Heap-typed {position} '{name}' has no ownership state in a nogc-enforced module ({provenance}) |
| `E1402` | Owned value '{name}' is sealed into managed storage inside a nogc-enforced module ({provenance}) |
| `E1403` | Heap value '{name}' crosses implicitly out of a nogc-enforced module ({provenance}) |
| `E1404` | '{name}' is `any`-typed and could be heap-allocated in a nogc-enforced module ({provenance}) |
| `E1405` | Closure capture of '{name}' escapes its scope in a nogc-enforced module ({provenance}) |
| `E1406` | '{name}' has retaining or aliasing semantics not supported in a nogc-enforced module ({provenance}) |

### Type-Only Import Bindings

| Code | Message |
|------|---------|
| `E1131` | '{name}' is a type-only export of '{module}'{scope} and must be imported with `import type` |
| `E1132` | '{name}' was imported with `import type` and cannot be used as a value |

!!! tip "Fixing `E1131` (a type-only export reached by a plain import)"
    `E1131` asks whether the backend lowering *this* module leaves a runtime binding for the imported name. Two cases reach it. A TypeScript `interface` or `type` alias in a `.d.ts` (npm package or sibling declaration file) declares no runtime export in any codespace, so a plain import of one is always refused. A jac `type` alias is refused **only in client code**: the Python backend lowers an alias to a real runtime binding (a `TypeAliasType`, or a plain `UserId = int` for a distinct alias `type UserId := int`, which is what makes `UserId(raw)` a brand constructor), and only the client backend erases it -- so a plain import of an alias from a server module is correct and must stay that way. Where the error does fire, move the name to its own `import type from <module> { Name }` statement and leave the value imports from that module where they are. `declare class`, `declare enum`, and every jac archetype (`obj`, `class`, `node`, `edge`, `walker`, `enum`) have a runtime binding on both backends, so a plain import of one stays correct; a package with no declarations at all is a value import as before (`W1102` / `E1120`). The error blocks codegen. See [Type-Only Imports](language/types-and-values.md#type-only-imports-import-type).

!!! tip "Fixing `E1132` (a type-only binding used as a value)"
    An `import type` binding is registered with the checker and nothing else -- neither backend emits a runtime import for it -- so calling it, reading an attribute off it, passing it to `isinstance`/`issubclass`, decorating with it, inheriting from it, or assigning it reaches a name nothing binds. This holds on the server too: the `typing.TYPE_CHECKING` guard means a guarded `UserId(raw)` would be a `NameError`, not a brand. Annotations, `has` field types, return types, generic arguments, `as` casts, and `type` alias right-hand sides are type position and stay legal. If the name really is needed at runtime, import it with a plain `import from` instead, which requires that it actually has a runtime binding in the importing module's codespace. The error blocks codegen.

### Type Warnings

| Code | Message |
|------|---------|
| `W1036` | Generic type "{type}" used without type arguments, defaulting to "{type}[Any]"; consider adding explicit type arguments |
| `W1037` | Explicit 'any' type annotation disables type checking here; consider a more specific type |
| `W1050` | Unknown intrinsic JSX element '<{tag}>' |
| `W1051` | Expression type could not be resolved (Unknown) |
| `W1052` | JSX component '{component}' uses an untyped props bag (`props: any`); its JSX props cannot be type-checked |
| `W1310` | Region open on '{name}' has an empty body |
| `W1312` | Owned value '{name}' silently seals into managed storage |

---

## Import Warnings (W1xxx)

| Code | Message |
|------|---------|
| `W1100` | Module not found |
| `W1101` | Cannot import name '{name}' from module '{module}' |
| `W1102` | Imported name '{name}' from foreign-source module '{module}' typed as Any |
| `E1120` | Import of '{name}' from untyped external module '{module}' (no type declarations found) |
| `W1103` | '{name}' is ambient and does not need to be imported from '{module}' |
| `W1105` | Local module '{name}' shadows the npm package of the same name |

---

## Import Errors (E11xx)

Emitted by `StaticAnalysisPass` for refused `import from` items. All three block codegen. Only the from-import item form is refused: the module form (`import typing;` then `typing.Any`) stays legal.

| Code | Message |
|------|---------|
| `E1122` | 'Any' cannot be imported from 'typing' -- use jac's builtin `any` |
| `E1123` | '{name}' cannot be imported from 'typing' -- use the builtin `{remedy}` |
| `E1125` | '{name}' is ambient and cannot be imported from '{module}' |

!!! tip "Fixing `E1122` (importing `Any` from typing)"
    Jac has its own `any` and will not carry an aliased twin: the two spell the same type, so a second name for it is redundant. Drop `Any` from the import list (remove the import when it was the only name) and write the lowercase keyword instead -- `x: any`, `dict[str, any]`. If you need the runtime `typing.Any` object itself (reflection over annotations, not an annotation), reach it in module form: `import typing;` then `typing.Any`.

!!! tip "Fixing `E1123` (deprecated typing aliases)"
    Fires for the six deprecated typing aliases of builtins: `Dict` -> `dict`, `FrozenSet` -> `frozenset`, `List` -> `list`, `Set` -> `set`, `Tuple` -> `tuple`, `Type` -> `type`. The alias and the builtin spell the same type, and jac subscripts the builtin directly, so the alias buys nothing and costs an import. The `as`-renamed form (`List as L`) is refused too. Drop the name from the import list and write the builtin instead -- `list[int]`, not `List[int]`.

!!! tip "Fixing `E1125` (importing an ambient name)"
    Jac provides a curated set of typing constructs in every module's scope, so importing one is a second spelling of the same binding -- and when the source is `typing`, the import alone keeps the module off the native pathway. The ambient set (defined in `compiler/types/typing_ambient.pyi`) is: `Annotated`, `AsyncIterable`, `AsyncIterator`, `Awaitable`, `Callable`, `ClassVar`, `Coroutine`, `Generic`, `Iterable`, `Iterator`, `Literal`, `Mapping`, `MutableMapping`, `MutableSequence`, `Protocol`, `Sequence`, `TypeVar`. Each name is refused both from `typing` and from its real home module (`collections.abc` for the collection ABCs). Drop the name from the import list and keep writing it as before -- generated code re-imports ambient names automatically, so runtime annotation introspection still works. Binding a different local name on purpose stays legal: the `as`-alias form (`Callable as Cb`) is exempt. In the compiler's own bootstrap-compiled modules and the ambient-provider modules the finding downgrades to the advisory `W1103`.

---

## Semantic Errors (E2xxx / W2xxx)

Emitted by static analysis and declaration-implementation matching passes.

### Static Analysis

| Code | Message |
|------|---------|
| `W2001` | Name '{name}' may be undefined |
| `W2002` | Unreachable code detected |
| `W2003` | '{name}' is defined but never used |

### Semantic Errors

| Code | Message |
|------|---------|
| `E2004` | Non default attribute '{name}' follows default attribute |
| `E2005` | Missing "postinit" method required by uninitialized attribute(s) |
| `W2006` | '@classmethod' decorator is not recommended in '{kind}' definitions |
| `W2007` | '@staticmethod' is not supported in '{kind}' definitions |
| `E2008` | Invalid target for context update: {target} |
| `W2029` | '@{decorator}' is not recommended in '{kind}' definitions -- use native property syntax |

`W2029` covers the Python property decorators -- `@property`, and the same-object
`@x.getter` / `@x.setter` / `@x.deleter` -- in favour of [native property
syntax](language/functions-objects.md#6-properties-and-encapsulation):

```jac
obj Account {
    has _balance: float = 0.0,
        balance: float {
            getter -> float { return self._balance; }
            setter(value: float) { self._balance = value; }
        }
}
```

`jac check --lint --fix` rewrites the decorator form automatically
([`property-to-native`](#lint-rules-w3xxx-e3xxx)). As with `W2006`/`W2007`, a
Python-compat `class` is exempt. A cross-object `@Base.x.setter` extends a parent's
property and has no direct native form, so it is not reported.

### Declaration-Implementation Matching

| Code | Message |
|------|---------|
| `E2009` | Implementation could not be matched to a declaration |
| `W2010` | Abstract ability {name} should not have a definition |
| `E2011` | Parameter count mismatch for ability {name} |
| `E2012` | From the declaration of {name} |

### JSX Slot Body Rules

Emitted by `ViewLowerPass` when a `{...}` JSX slot's statement-template body violates the body-shape rules. See the [components tutorial](../tutorials/fullstack/components.md#jsx-slots-control-flow-as-children) for the underlying model.

| Code | Message |
|------|---------|
| `E2019` | A JSX slot renders template content and cannot 'return' a value. Use 'skip;' for slot early-exit, or move the value-producing expression outside the JSX slot. |
| `E2020` | Bare 'return;' is not allowed inside a JSX slot -- it reads like it exits the enclosing function, but a slot body is an inlined IIFE. Use 'skip;' for slot early-exit. |
| `E2021` | '{kw}' is not allowed inside a '{loop}' loop in a JSX slot. Use 'continue' to skip an iteration, or 'skip;' to exit the whole slot. |
| `E2022` | 'finally' is not allowed on a 'try' that has an 'awaiting' clause. The dispatched-but-not-joined window and finalization semantics are ambiguous together; move cleanup into an explicit mount/unmount hook or drop one of the clauses. |
| `E2023` | Redundant '{...}' slot wrapping inside a JSX slot body -- slot bodies are already in slot mode. Drop the outer braces: write '`<kw>` ... { ... }' directly instead of '{`<kw>` ... { ... }}'. |
| `E2024` | 'has' is not allowed inside a JSX slot body. A slot body is a statement template that re-runs on every render; declaring reactive state there would compile to a conditional 'useState' and violate React's rules of hooks. Declare 'has'-fields at the component scope (the enclosing 'def -> JsxElement' body). |
| `E2025` | A 'has'-field of type 'Ref[...]' must be constructed with an initializer: write '= Ref()' for a DOM ref, or '= Ref(initial)' for a value ref. It lowers to React's 'useRef', so a bare declaration has no ref object to hold -- '.current' would never be defined. This mirrors how every other 'has'-field carries a value. |
| `E2027` | Endpoint clause ': Src --> Tgt' is only valid on an 'edge' archetype, not on {arch_type} '{name}' |
| `E2084` | An expression without a trailing ';' is only treated as an implicit return when it is the final statement of a function, ability, or lambda body. |
| `W2019` | 'while' loop in a JSX slot renders JSX without a 'key' attribute -- add 'key=' so siblings keep their identity across re-renders. |
| `W2020` | 'awaiting' is not yet implemented on the '{target}' target -- the 'awaiting' clause body will be ignored at runtime. Only the 'cl' (react/preact) target currently lowers 'awaiting' to a Suspense fallback. |
| `W2021` | 'for' loop in a JSX slot renders JSX without a 'key' attribute -- annotate one child element with 'key=' so iteration siblings keep their identity across re-renders. |

---

## Lint Rules (W3xxx, E3xxx)

Emitted by `jac check --lint`. Rules can be configured in [`jac.toml`](config/index.md#checklint). The kebab-case name in brackets is used for `jac.toml` configuration.

| Code | Rule Name | Message | Group |
|------|-----------|---------|-------|
| `W3001` | `staticmethod-to-static` | @staticmethod should use 'static' keyword | default |
| `W3002` | `combine-has` | Consecutive 'has' declarations can be combined | default |
| `W3003` | `combine-glob` | Consecutive 'glob' declarations can be combined | default |
| `W3004` | `init-to-can` | '{name}' should use Jac keyword | default |
| `W3005` | `remove-empty-parens` | Empty parentheses can be removed | default |
| `W3007` | `hasattr-to-null-ok` | hasattr() should use null-safe access | default |
| `W3008` | `simplify-ternary` | Ternary can be simplified | default |
| `W3009` | `remove-future-annotations` | 'from \_\_future\_\_ import annotations' is unnecessary | default |
| `W3010` | `fix-impl-signature` | Implementation signature does not match declaration | default |
| `E3012` | `no-print` | Calling print() is disallowed by rule | all |
| `W3013` | `remove-redundant-semi` | Unnecessary semicolon | default |
| `W3020` | `unnecessary-pass` | Unnecessary 'pass' in non-empty body | default |
| `W3021` | `unnecessary-else-after-return` | Unnecessary 'else' after 'return' | default |
| `W3022` | `nested-if-to-elif` | Nested 'if' in 'else' can be 'elif' | default |
| `W3023` | `simplify-return-bool` | `if cond return True else return False` can be simplified to `return cond` | default |
| `W3024` | `repeated-condition` | Repeated condition in if/elif chain | default |
| `W3025` | `identical-branches` | Identical if/else branches -- the else is redundant | default |
| `W3030` | `too-many-params` | Function has {count} parameters (threshold is {threshold}) | default |
| `W3035` | `is-with-literal` | Use '==' instead of 'is' when comparing to a literal | default |
| `W3036` | `mutable-default` | Mutable default argument '{type}' -- use None and assign inside the function | default |
| `W3037` | `unnecessary-none-return` | Unnecessary '-> None' return type annotation on '{name}'; functions without a return statement implicitly return None | default |
| `W3038` | `usestate-to-has` | useState hook for '{name}' can be replaced with `has {name}: {type} = {init}` | default |
| `W3039` | `getattr-to-null-ok` | getattr(obj, 'attr', None) should use null-safe access | default |
| `W3040` | `filter-compare-tautology` | Filter comparison '{name} == {name}' is always true | default |
| `W3041` | `stale-has-read` | Reactive `has` field '{name}' is read after being assigned in the same `can with entry` block | default |
| `W3042` | `map-lambda-to-comprehension` | `.map(lambda x -> any { return <jsx>; })` can be replaced with comprehension syntax | default |
| `W3050` | `strip-comments` | Comment can be removed | opt-in |
| `W3051` | `strip-docstrings` | Docstring can be removed | opt-in |

> **opt-in group**: `strip-comments` and `strip-docstrings` are destructive "deslop" rules. They are **never** activated by `select = ["all"]` or `["default"]`; they fire only when named explicitly in [`[check.lint]`](config/index.md#checklint). See the config reference for details.

---

## Codegen Errors (E5xxx / W5xxx)

Emitted during code generation, formatting, and native compilation.

### JCIR Generation

Emitted while lowering the unitree into the compact codegen IR container (`JcirGenPass`) that the Python-bytecode backend compiles.

| Code | Message |
|------|---------|
| `E5001` | String literal imports are only supported in client-placed imports |
| `E5002` | {import_type} imports are only supported in client-placed imports |
| `E5003` | Archetype has no body. Perhaps an impl must be imported. |
| `E5004` | Abstract ability {name} should not have a body |
| `E5005` | Ability has no body. Perhaps an impl must be imported. |
| `E5006` | Invalid pipe target |
| `E5007` | Binary operator {op} not supported in bootstrap Jac |
| `E5008` | Invalid attribute access |
| `E5010` | Spawn expressions must include a walker constructor on one side |
| `E5011` | Expected expression in spawn argument |
| `E5012` | Expected main module to be a Module node |
| `W5013` | Both sides of spawn look like walker instantiations; defaulting to right-hand |
| `W5014` | Walker spawn has more positional arguments than fields |

### Native Compilation

| Code | Message |
|------|---------|
| `E5020` | Native compilation failed: {error} |
| `W5021` | C library not found: {path} |
| `W5022` | Failed to load C library '{path}': {error} |
| `E5026` | Symbol collision during native link: '{symbol}' is defined in both '{existing_module}' and '{new_module}' |

### Layout Pass

| Code | Message |
|------|---------|
| `E5030` | Cannot compute C3 MRO for {name}: inconsistent hierarchy |
| `W5031` | obj '{arch}' field '{field}' has no type annotation |
| `W5032` | obj '{arch}' field '{field}' has type '{type}' which is not layout-compatible |

### Bytecode Generation

| Code | Message |
|------|---------|
| `E5040` | Unable to find AST for module {path} |
| `E5041` | Length mismatch in import names |
| `E5042` | Length mismatch in async for body |

### Formatter / Comment Injection

| Code | Message |
|------|---------|
| `W5050` | Comment could not be placed precisely; emitting near end of formatted output |
| `E5051` | Formatter displaced {count} comment(s) to end of file -- refusing to save |

### Native IR Generation

| Code | Message |
|------|---------|
| `E5060` | C library import declaration '{name}' must not have a body |

### Client Code Generation

| Code | Message |
|------|---------|
| `E5080` | Argument '{name}' for server function '{func}' is given both positionally and by keyword |
| `E5081` | Unknown client framework '{framework}' |
| `E5082` | Client code imports '{name}' from '{module}', but '{name}' has no client-side presence |
| `E5084` | Client code uses '{name}' from bare import '{module}', which resolves to no client-reachable module |
| `E5086` | Client code emits '{name}', which has no binding in the client bundle |
| `E5087` | Project kind '{kind}' has no server, but '{name}' needs one ({reason}) |
| `E5101` | Client codegen emitted '{name}', which the module never binds |

`E5082` fires when a plain client import references a server symbol that does not bridge: server `def:pub` endpoints bridge automatically over RPC, so the fix is to make the symbol a `def:pub` endpoint, pin it (or its module) `"client"` via `[placement.pins]`, or move it into client code.

`E5084` is the bare-import sibling. A bare name resolves across the module universe -- local Jac module first, then Python, then the client npm world (jac.toml `[dependencies.npm]`, the active framework's own packages, and whatever is installed under `.jac/client/node_modules`), so `import from react { useRef }` works unquoted. When the name resolves to none of those client-reachable worlds, placement pins the import server-side, the bundle never binds the symbol, and the page would fail at runtime with a ReferenceError -- so client use fails the build instead. Install or declare the package in `[dependencies.npm]` (or quote the module to pin the npm form), or keep the use server-side behind a `def:pub` endpoint. Annotation-only uses do not fire it, since ES output erases type annotations; imports whose uses are all server-side prune silently as before.

`E5086` covers the same failure for a *module's own* declarations rather than its imports. The bundle carries what is placed in the client codespace, plus `def:pub` endpoints, which are bound to a generated client-side forwarder that calls them over RPC. Anything else named by client code -- a function pinned `"server"` via `[placement.pins]`, a glob kept server-side -- would emit as a bare identifier that resolves to nothing. That is a guaranteed `ReferenceError` at module load, so it fails the build at the seam that produces the artifact. Give the element client presence (drop the pin, or make it `def:pub`), or keep the use out of client code.

`E5101` is the backstop under all of the above, and it checks the finished artifact rather than the reasoning that produced it. After the client module is emitted, every identifier it references is matched against the module's own declarations, its imports, its parameters, and the ambient surface a browser provides (the same `js_globals` / `dom_types` stubs `jac check` resolves client-tier names against). What is left over is then narrowed to names the compiler itself resolved in Jac: a name with a symbol, emitted with nothing to bind it, is a `ReferenceError` on first use with `jac check` green and the build exiting 0. Give the name client presence (declare it, import it, or make it a `def:pub` endpoint so it bridges); reach a host global the compiler does not know about through `globalThis` so the intent is explicit; and if neither applies, a lowering dropped a binding it owed, which is a compiler bug worth reporting with the source line. Declarations count wherever they appear in the module rather than per scope, so the check never fires on a name that is bound somewhere. A name that resolves to nothing in Jac either is still presumed to be an undeclared ambient global and is not reported here -- requiring those to be declared is tracked separately.

`E5087` fires when a project kind with no server contains code that needs one: root access, an FFI extern, an inline `::py::` block, or a Python import whose bindings are used at value level. A `js-package` ships as an npm tarball with nothing serving `/function/<name>`, so server placement there could only fail at runtime inside a `fetch` that has no route to reach. Annotation-only and `import type` uses stay silent, on the same criterion `E5084` uses.

---

## Client Codespace Warnings (W6xxx)

### Cross-Codespace Portability

Emitted by `CapabilityCheckPass` when code uses JS-specific surface instead of Jac's common primitives, which work across all codespaces (Python, JS, native).

| Code | Message |
|------|---------|
| `W6001` | Use of JS-specific global '{name}' -- use '{alternative}' for cross-codespace portability |
| `W6002` | Use of JS-idiomatic method '.{method}()' -- use '{alternative}' for cross-codespace portability |
| `W6003` | Use of JS-specific keyword '{name}' -- use '{alternative}' for cross-codespace portability |
| `W6004` | Use of JS-specific property '.{prop}' -- use '{alternative}' for cross-codespace portability |

### RPC Boundary

| Code | Message |
|------|---------|
| `W6005` | Client call to server endpoint '{func}' passes function-typed parameter '{param}' -- functions cannot cross the RPC boundary |

A `def:pub` function in a server-placed module is an HTTP endpoint whose arguments serialize over the wire, so a function-typed argument cannot cross it. Shared client-side logic should drop `:pub` so it is placed in the browser with its callers.

### Placement Boundary

| Code | Message |
|------|---------|
| `W6006` | Mutable glob '{name}' is emitted into both the server and the client -- each side gets an independent copy (state fork) |
| `W6007` | Client code uses server-placed function '{name}' as a value -- function values cannot cross the placement boundary |
| `W6009` | Client binding for server endpoint '{name}' is async: it hands back a Promise where the server function hands back '{ret}' |

`W6006`: dual emission duplicates *state*, not just code -- server writes and client writes land in different copies of the glob. Home the glob with its writers by pinning it (or its module) in `jac.toml` -- `[placement.pins] "mod.the_glob" = "server"` (or `"client"`) -- or bridge reads through a `def:pub` accessor.

`W6007`: the value-flow generalization of `W6005`. A function reference that flows into client-side data (stored in a container, returned, or passed along as an argument) needs client presence. A `def:pub` endpoint gets that presence automatically, through a generated client-side forwarder, so this fires only where no forwarder is possible -- a function with no endpoint access, or one pinned server. Drop the pin, or restructure so the client stores data instead of the function. The build-time form of the same fact is `E5086`. See [Placement](placement.md) for the full model.

`W6009`: the forwarder that gives a `def:pub` endpoint its client-side presence calls the endpoint over HTTP, so it is necessarily `async` and its result is a `Promise<T>` where the server function's is `T`. That is transparent where the result is awaited or ignored (a command handler, an event listener) and wrong where a plain value is required (a sort comparator, a reducer). Await the call, or drop `:pub` so the function is placed client-side and stays synchronous.

---

## Dev Loop and Client Runtime Errors (E7xxx)

Emitted at run time, not by `jac check`. The dev loop (`jac run --dev`) and the
`/cl/__error__` endpoint classify every failure the browser, the Vite dev server
or the client build reports, resolve it back to a Jac location through the
client source maps, and render it in the shape above. The 7-series is grouped by
*channel* rather than by compiler phase, so `E7005` carries the `codegen`
category while the rest carry `runtime`.

| Code | Message |
|------|---------|
| `E7001` | The module '{module}' has no export named '{name}' |
| `E7002` | Failed to resolve import '{name}' from '{importer}' |
| `E7003` | Uncaught {kind} in client code: {message} |
| `E7004` | Vite dev-server error: {message} |
| `E7005` | Client build failed: {message} |
| `E7006` | Client error could not be traced to Jac source: {message} |

`E7001` is the link error the browser raises when a module loads and the name a
value import asked for is not among its runtime exports. The usual cause is a
type-only export -- a TypeScript interface or type alias that lives in the
package's `.d.ts` and is erased before the module runs. Import it with
`import type`, or check the package's exports for the name's real spelling. The
location is the `.jac` import item itself, found through the compiled module's
column map.

`E7002` is a resolve failure the dev server raises before the browser ever runs
the module. The primary location is the importing `.jac` line; when the missing
name is a bare npm package, the diagnostic also carries a related location on
the `jac.toml` `[dependencies.npm]` table -- the package's own line when it is
declared, the table header when it is not, and the file itself when the table is
absent. `W1106` is the build-time sibling for the same fact and owns the
undeclared-package wording, which `E7002` reuses verbatim rather than
duplicating.

`E7003` is any error the browser threw with a stack. The topmost frame that maps
into a `.jac` file is the reported location; the raw JavaScript stack is kept on
the diagnostic so frames outside your sources are not lost.

`E7005` covers the client build failures that reach the dev loop as a bare
exception. Whenever the compiler emitted diagnostics of its own, those are
reported instead, with their real codes and locations.

`E7006` is the honest answer when nothing on disk claims the location the
browser reported -- a browser extension, a dependency with no source map, or an
artifact from a build that has since been replaced. The `file` field still names
the best-known Jac owner and the diagnostic carries an explicit
`unmapped_reason`; it is never silently empty.

---

## Internal Compiler Errors (E9xxx)

These indicate bugs in the compiler itself. If you encounter one, please [file an issue](https://github.com/jaseci-labs/jaseci/issues).

| Code | Message |
|------|---------|
| `E9001` | ICE: Pass {pass_name} -- {details} |
