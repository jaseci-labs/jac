---
name: jac-impl-files
description: Splitting declarations from method bodies via impl blocks, .impl.jac files, impl/ and .impl/ directory layouts, client-component handler annexes, variant modules (.sv/.cl/.na), .test.jac annexes, and package layout. Load when a source file grows past ~100 lines, or to separate a clean public-API surface from implementation.
---

A `.jac` file declares fields, enums, method signatures. Implementations live in `impl <name>` blocks - inline in the same file, or in auto-discovered `.impl.jac` annex files. The compiler auto-pairs them by **basename** - no `import` between them. Three layouts work (all verified):

| Layout | Files | Use for |
|---|---|---|
| Side-by-side (1:1) | `mod.jac` + `mod.impl.jac` in the same dir | medium modules |
| Shared `impl/` dir | `mod.jac` + `impl/mod.impl.jac` | packages with several modules - **the dominant pattern** in the Jac codebase itself |
| `mod.impl/` dir (1:many) | `mod.jac` + `mod.impl/<feature>.impl.jac` (any names) | one big type, impls split by feature (`tuples.impl.jac`, `errors.impl.jac`, ...) |

Decision tree (compressed): mostly data types, few methods → no impl files at all. Total under ~100 lines → keep `impl` blocks inline. One class, 20+ methods spanning concerns → `mod.impl/` directory. Several related modules in a package → shared `impl/` directory. Otherwise → side-by-side. Be consistent within a package.

Single-file form (declaration + impl together - runnable as-is):

```jac
import math;

obj Shape {
    has name: str;
    def area -> float;
}

obj Circle(Shape) {
    has radius: float;
    override def area -> float;
}

impl Shape.area -> float {
    return 0.0;
}

impl Circle.area -> float {
    return math.pi * self.radius * self.radius;
}

with entry {
    print(Circle(name="c", radius=5.0).area());
}
```

Same code split: `shapes.jac` holds everything EXCEPT the two `impl` blocks; `shapes.impl.jac` (or `impl/shapes.impl.jac`) holds them.

## Declaration → matching impl forms

| In `.jac` | In `.impl.jac` |
|---|---|
| `def fn_name;` | `impl fn_name { body }` |
| `def fn_name(args) -> T;` | `impl fn_name(args) -> T { body }` |
| `def Obj.method(args) -> T;` | `impl Obj.method(args) -> T { body }` |
| `can event with NodeType entry;` | `impl Walker.event { body }` |
| `async def loadData -> None;` (handler stub inside a `def:pub` component) | `impl app.loadData -> None { body }` - `has` state is in scope bare, no `self.` (see below) |
| `obj X;` (decl-only archetype; also `node X;` etc.) | `impl X { has f: int = 0; def m -> int { ... } }` - the whole body |
| `enum Color;` | `impl Color { RED = "r", GREEN = "g" }` |
| `enum Color: int;` (typed-base) | `impl Color { RED = 1, GREEN = 2 }` |
| `override def method;` (subclass) | `impl Subclass.method { body }` |
| property accessor decls `getter -> T; setter(v: T);` | `impl Obj.prop.getter -> T { body }` / `impl Obj.prop.setter(v: T) { body }` |
| `def method -> T abst;` (abstract) | (none on base - every subclass *should* `impl`; not compiler-enforced - see Rules) |

## Client components: the handler annex

The standard answer to "my client component file is too big": declare the async handlers as **stubs inside the component**, implement them in the paired `.impl.jac`. This is how the `jac create --use web-app` scaffold ships and the dominant pattern in real Jac frontends - the component `.jac` stays a readable state-plus-render surface while fetch/mutate bodies live next door. Inside an `impl app.handler`, the component's reactive `has` fields are read and written **bare** - `items = ...`, never `self.items` - and assignments re-render exactly as they would inline. `root spawn walker(...)` and `await sv_fn(...)` calls work the same as in the component body.

```jac
# frontend.jac - state + stubs + render
def:pub app -> JsxElement {
    has items: list[str] = [],
        draft: str = "",
        loading: bool = False;

    can with entry { loadItems(); }

    async def loadItems -> None;            # handler stubs - bodies in the annex
    async def addItem -> None;

    return <div>
        <input value={draft} onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}/>
        <button onClick={addItem}>Add</button>
        {if loading { <p>Loading...</p> }}
        {for it in items { <li key={it}>{it}</li> }}
    </div>;
}

# frontend.impl.jac - bodies; `has` state is bare (no self.), writes re-render
impl app.loadItems -> None {
    loading = True;
    items = ["first", "second"];            # real code: await a sv import call here
    loading = False;
}

impl app.addItem -> None {
    if not draft.strip() { return; }
    items = items + [draft];
    draft = "";
}
```

(Shown as one file - it also compiles merged - but in practice the `impl` blocks go in `frontend.impl.jac`, paired by basename as usual.) The annex sees the head file's imports, including `sv import` stubs. Architecture-level guidance (stateful shell, prop-drilled sections) is in `jac-cl-organization`.

## Rules

- **Same basename pairs the files** - `foo.jac` ↔ `foo.impl.jac`, whether the annex sits beside it, in `impl/`, or (1:many, any filenames) in `foo.impl/`. Do NOT "fix" a working `impl/` layout by flattening it.
- **No `import` between the pair.** Compiler auto-pairs. `import from foo.impl { ... }` is wrong.
- **Signature must match exactly.** `impl fn(x: int) -> str` paired with `def fn(y: str);` fails. Bare `impl fn { ... }` only matches bare `def fn;`.
- **Decl+impl, not decl+decl.** A second `obj X { ... }` block with the same name is E0077 (duplicate declaration). And **no forward declarations are needed** - Jac resolves all module symbols before checking bodies, so types can reference each other in any order.
- **`abst` = abstract, but not enforced** - a subclass missing its `impl` still passes `jac check`, still instantiates, and the un-implemented method silently returns `None`. Treat `abst` as intent-signalling. (The keyword is `abst`; `abs` is only the builtin function.)
- **`override def` is required on subclass overrides.** Without it, `def play;` in a subclass is a NEW method that shadows - doesn't override.
- **Bodies in `.impl.jac` see the `.jac` file's imports.** Don't re-import inside the impl file. Private `_helpers` used only by impls belong in the impl file.

## Other annexes and module variants

- **`.test.jac`**: `mod.test.jac` is the test annex - `test name { assert ...; }` blocks that see `mod`'s symbols without imports; run with `jac test` (see `jac-testing`).
- **Variant modules**: placement is inferred, so a plain `.jac` module is the default; the `.sv`/`.cl`/`.na` suffixes are the explicit form for splitting one logical module across codespaces (see `jac-codespaces`). `mod.sv.jac` (server), `mod.cl.jac` (client), `mod.na.jac` (native) are auto-discovered and merged into one logical module `mod`. Head-module precedence: `.jac` > `.sv.jac` > `.cl.jac` > `.na.jac` - the highest-precedence existing file is the head; the rest attach as variant annexes. Variant impls pair by full name (`mod.sv.impl.jac` implements `mod.sv.jac` decls); a head `mod.impl.jac` may implement declarations from *any* variant.
- **Packages need no `__init__.jac`.** Any directory with `.jac` files is importable (`import from utils.math_utils { add }`). Add `__init__.jac` only as a re-export barrel (`import from .operations { add }` so consumers write `import from mathlib { add }`) or for package-init code.

## See also

`jac-has-fields` (property accessor blocks) · `jac-testing` (`.test.jac`, `jac test`) · `jac-cl-organization` (shell-component architecture using the handler annex) · `jac-core-cheatsheet` (import dot semantics) · `jac-packaging` (shipping packages)
