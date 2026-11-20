---
name: jac-comptime
description: Compute values and specialize code at compile time. Use for comptime declarations, reflection, embedding, or E0033/E0108/E0109 diagnostics.
---

`comptime` marks a value the compiler computes while the module compiles. It is a property of values, not a macro system: an expression is comptime-known when it is built from literals, other comptime values, enum members, types, and the program's own declarations. The same Jac is interpreted by the compiler; there is no second language.

```jac
comptime import from jaclang.comptime { fields, members }

enum Suit {
    HEARTS,
    SPADES
}

comptime SUITS: int = len(members(Suit));    # module-level binding, folded to 2
comptime assert SUITS == 2, "two suits";      # module-level assert, fails the build

obj Window {
    has title: str,
        width: int = 800;

    def to_dict -> dict[str, any] {
        out: dict[str, any] = {};
        comptime for f in fields(Window) {   # unrolled over the declared has-fields
            out[f.name] = getattr(self, f.name);
        }
        return out;
    }
}

def repeat(comptime n: int, msg: str) -> str {
    out = "";
    comptime for _ in range(n) {
        out += msg;
    }
    return out;
}

with entry {
    print(repeat(3, "ab"), Window(title="t").to_dict());
}
```

## The forms

| Form | Meaning |
|------|---------|
| `comptime NAME: T = expr;` | Binding evaluated at compile time; module level, inside a body, or inside an `obj` body |
| `comptime if cond { } else { }` | Condition must be comptime-known; the losing branch is removed before any backend sees it |
| `comptime for x in coll { }` | `coll` must be comptime-known; `x` is a comptime value in the body |
| `comptime assert cond, "msg";` | Fails the build with E0109; nothing remains at runtime |
| `comptime def f(...) { }` | Exists only at compile time; calls from runtime sites are folded or reported |
| `comptime import from m { x }` | Import for compile-time use only; erased from every backend |
| `def f(comptime n: int, ...)` | Every call must pass a comptime-known `n` |
| `obj M[T, comptime n: int] { }` | Value parameter; instantiate as `M[float, 4](...)` |

## Rules that bite

- **Comptime-known means literal-derived.** A `glob`, a parameter without `comptime`, `input()`, `os.environ`, or anything read at runtime is not comptime-known: E0033 names the site and the first non-comptime leaf.
- **Comptime code is pure.** No I/O, no foreign calls, no walkers, no `match`/lambdas/generators/`async`/`with`; a raise inside comptime code is E0108 with the reason. Work is fuel-limited; `set_fuel(n)` raises the budget for a known-large computation.
- **`comptime import` names are compile-time only.** A comptime-imported name used at a runtime site is inlined when it materializes (scalar, container, enum member, type, function reference) and E0033 otherwise. A `comptime def` in another module is reachable only through `comptime import`.
- **`comptime if` on a `comptime` parameter is a runtime `if` on the Python and client tiers** (the parameter erases to an ordinary one there; only the native tier stamps one body per value). A native-only construct is provably safe only under a `comptime if` whose condition does not depend on the parameter (`codespace.is_native`).
- **Archetype value params erase to fields.** `M[float, 4](...)` binds `n` as a constructor-bound field on every tier; methods read `n` as a plain name; `M[float, 4].SIZE` folds at the site; `M(...)` without the subscript is E0033. All instantiations share one struct layout.
- **The intrinsic is `get_field`, not `field`.** `field` would shadow the `dataclasses.field` the generated Python imports. Use `getattr` in runtime code and `get_field`/`set_field` in comptime code.
- **Records with `init`/`postinit` run them at compile time** and materialize through `jaclang.comptime.record(...)`; on the native tier only scalars, strings, bytes, and `None` become constants, so `comptime for f in fields(T)` is a Python/client idiom.

## Intrinsics (`import from jaclang.comptime { ... }`)

`typeof(v)`, `fields(T)` (list of `FieldInfo`: `name`, `type`, `has_default`, `default`, `semstr`), `get_field(x, name)`, `set_field(x, name, v)`, `has_field(T, name)`, `members(E)`, `semstr(T)`/`semstr(T, field)`, `name(fn)`, `module_of(v)`, `is_subtype(A, B)`, `sizeof(T)`/`alignof(T)`, `embed_file(path)`/`embed_bytes(path)` (relative to the module, tracked as a cache dependency), `set_fuel(n)`, `codespace` (`is_python`/`is_client`/`is_native`), `target` (`os`, `arch`, `pointer_width`). Every intrinsic has a runtime fallback, so a plain `import` of it also works.

## Diagnostics

| Code | Meaning | Fix |
|------|---------|-----|
| `E0033` | A comptime site received something not known at compile time | Make the operand literal-derived, mark the parameter `comptime`, or move the check to runtime |
| `E0108` | Compile-time evaluation failed (raise, forbidden construct, fuel, cycle) | Read the reason; keep comptime code pure and bounded |
| `E0109` | `comptime assert` was false | The message is the assertion text; fix the invariant or the data |

## Pitfalls

- `comptime x = 1; x += 1;` does not make `x` a mutating comptime variable; the `+=` is a runtime assignment. Accumulate inside a `comptime for` or a `comptime def`.
- A comptime type binding (`comptime Cell: type = pick(True);`) can be instantiated (`Cell(v=7)`) but is not yet usable as an annotation (`has c: Cell;`).
- Writing `comptime` inside compiler seed modules is refused by the seed gate; user code, the CLI, and the runtime are all fine.

## See also

`jac-types` (generics, `Self`, fixed-width numbers) · `jac-has-fields` (what `fields(T)` reflects) · `jac-native` (what lowers natively) · `jac-core-cheatsheet` (reserved words; `comptime` needs a backtick as an identifier)
