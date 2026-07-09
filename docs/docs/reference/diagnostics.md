# Errors and Warnings

The Jac compiler uses a structured diagnostic code system. Every error, warning, and note has a unique code that identifies the issue and can be used for inline suppression.

## Code Format

Diagnostic codes follow the pattern `{severity}{category}{sequence}`:

- **Severity**: `E` (error) or `W` (warning)
- **Category digit**: `0` = syntax, `1` = type, `2` = semantic, `3` = lint, `4` = import, `5` = codegen, `9` = internal
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
- `-e` / `--diagnostics` on `jac run` controls diagnostic verbosity: `error` (default -- fail on errors with full details), `all` (errors + warnings), or `none` (silent)

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

### Operator / Expression Errors

| Code | Message |
|------|---------|
| `E0020` | Walrus operator ':=' requires a simple name on the left side |
| `E0021` | Expected `:<+` or `:+>` to close connect operator |
| `E0022` | Expected ':' or '{' after lambda parameters |
| `E0023` | Expected augmented assignment in for...to...by step |

### Statement-Level Errors

| Code | Message |
|------|---------|
| `E0030` | Unexpected semicolon at module level |
| `E0031` | Module-level 'with' blocks only support 'entry', not 'exit' |
| `E0032` | Unexpected '{token}' -- must follow its parent statement (if/try/match/switch) |
| `E0034` | Expected 'with' after 'can' ability name (use 'def' for function-style declarations) |

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

### Parameter List Errors

| Code | Message |
|------|---------|
| `E0050` | Duplicate '{param}' in parameter list |
| `E0051` | '{first}' must appear before '{second}' in parameter list |

### Property Declaration Errors

| Code | Message |
|------|---------|
| `E0080` | Property declarations cannot have an initializer (declare backing storage as a separate `has` field) |
| `E0081` | Property declaration must contain at least one of `getter`, `setter`, `deleter` |

### Parser Warnings

| Code | Message |
|------|---------|
| `W0060` | Docstrings in Jac go before the declaration, not inside the body |
| `W0061` | Parenthesized filter syntax `(?:...)` is deprecated. Use bracket syntax `[?:...]` instead. |
| `W0062` | `'root()'` is deprecated. Use bare `'root'` instead. |
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
    A common trigger for `E1001` and `E1002` is Jac's strict gradual-typing rule: in `.jac` source, an `any` value cannot silently flow into a declared non-`any`, non-`object` destination. Ways to clear it -- type the source (e.g. `has reports: list[T]` on a walker, `.pyi` stub on a Python utility), drop the annotation (`x = src()` makes `x` inferred-`any`), annotate `any` explicitly (`x: any = src()`) and narrow before downstream use, or re-type at the use site with the [`as` cast](language/foundation.md#10-the-as-cast-operator) (`src() as list[T]`) when you know more than the checker. See [The `any` Type and Gradual Typing](language/foundation.md#the-any-type-and-gradual-typing).

### Operator Errors

| Code | Message |
|------|---------|
| `E1010` | Operator "{op}" not supported for type "{type}" |
| `E1011` | Unsupported operand types for {op}: {left} and {right} |

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
| `E1095` | Field '{field}' declared 'by postinit' is never assigned in {arch}.postinit |

### Connection Type Errors

| Code | Message |
|------|---------|
| `E1096` | Connection left operand must be a node instance |
| `E1097` | Connection right operand must be a node instance |
| `E1098` | Connection type must be an edge instance |
| `E1099` | Cannot access attribute "{attr}" for type "{type}"; attribute is missing from {missing} |

### mobUI-Project JSX Host Tags

Emitted by `JsxIntrinsicGuardPass` when a `mobui` project (see [React Native target](plugins/jac-client.md#react-native-target-beta)) uses a raw HTML host tag in JSX. The guard resolves every tag name in the enclosing scope; only **unresolved lowercase names** are treated as HTML host elements and rejected. Uppercase components and lowercase components that resolve to an in-scope symbol are allowed. `.cl.jac` web-boundary files (but not `.native.cl.jac` files, which target React Native) and modules outside the project root are exempt; the client kind is discovered from each module's own project `jac.toml`, never the process cwd.

| Code | Message |
|------|---------|
| `E1105` | JSX tag '<{tag}>' is not in scope in a mobUI project; use {suggestion} instead |

!!! tip "Fixing `E1105`"
    `E1105` fires only in `mobui` projects (`[project] client_kind = "mobui"` in `jac.toml`). Replace the HTML tag with the suggested `@jac/mobui` primitive: `div`/`section`/`main` -> `View`, `span`/`p`/`h1`-`h6` -> `Text`, `button` -> `Pressable`, `input`/`textarea` -> `TextInput`, `img` -> `Image`, `ul`/`ol` -> `ScrollView`. If the lowercase name is meant to be a component, import it so it resolves in scope. Web projects (`client_kind` unset) are unaffected -- HTML tags remain valid there.

### Type Warnings

| Code | Message |
|------|---------|
| `W1036` | Generic type "{type}" used without type arguments, defaulting to "{type}[Any]"; consider adding explicit type arguments |
| `W1050` | Unknown intrinsic JSX element '<{tag}>' |
| `W1051` | Expression type could not be resolved (Unknown) |
| `W1052` | JSX component '{component}' uses an untyped props bag (`props: any`); its JSX props cannot be type-checked |

---

## Import Warnings (W1xxx)

| Code | Message |
|------|---------|
| `W1100` | Module not found |
| `W1101` | Cannot import name '{name}' from module '{module}' |
| `W1102` | Imported name '{name}' from foreign-source module '{module}' typed as Any |
| `W1103` | '{name}' is ambient and does not need to be imported from '{module}' |
| `W1104` | Use the lowercase `any` keyword instead of importing `Any` from typing |

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
| `W2019` | 'while' loop in a JSX slot renders JSX without a 'key' attribute -- add 'key=' so siblings keep their identity across re-renders. |
| `W2020` | 'awaiting' is not yet implemented on the '{target}' target -- the 'awaiting' clause body will be ignored at runtime. Only the 'cl' (react/preact) target currently lowers 'awaiting' to a Suspense fallback. |
| `W2021` | 'for' loop in a JSX slot renders JSX without a 'key' attribute -- annotate one child element with 'key=' so iteration siblings keep their identity across re-renders. |

---

## Lint Rules (W3xxx / E3xxx)

Emitted by `jac check --lint`. Rules can be configured in [`jac.toml`](config/index.md#checklint). The kebab-case name in brackets is used for `jac.toml` configuration.

| Code | Rule Name | Message | Group |
|------|-----------|---------|-------|
| `W3001` | `staticmethod-to-static` | @staticmethod should use 'static' keyword | default |
| `W3002` | `combine-has` | Consecutive 'has' declarations can be combined | default |
| `W3003` | `combine-glob` | Consecutive 'glob' declarations can be combined | default |
| `W3004` | `init-to-can` | '{name}' should use Jac keyword | default |
| `W3005` | `remove-empty-parens` | Empty parentheses can be removed | default |
| `W3006` | `remove-kwesc` | Unnecessary keyword escape on '{name}' | default |
| `W3007` | `hasattr-to-null-ok` | hasattr() should use null-safe access | default |
| `W3008` | `simplify-ternary` | Ternary can be simplified | default |
| `W3009` | `remove-future-annotations` | 'from \_\_future\_\_ import annotations' is unnecessary | default |
| `W3010` | `fix-impl-signature` | Implementation signature does not match declaration | default |
| `W3011` | `remove-import-semi` | Unnecessary semicolon after import | default |
| `E3012` | `no-print` | Calling print() is disallowed by rule | all |
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

### Python AST Generation

| Code | Message |
|------|---------|
| `E5001` | String literal imports are only supported in client (cl) imports |
| `E5002` | {import_type} imports are only supported in client (cl) imports |
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
| `W5023` | Native module not found: {path} |
| `W5024` | Failed to compile native module {path}: {error} |
| `W5025` | Failed to link native module {path}: {error} |

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

---

## Internal Compiler Errors (E9xxx)

These indicate bugs in the compiler itself. If you encounter one, please [file an issue](https://github.com/jaseci-labs/jaseci/issues).

| Code | Message |
|------|---------|
| `E9001` | ICE: Pass {pass_name} -- {details} |
