---
name: jac-impl-files
description: Splitting an archetype's declarations from its method bodies into companion `.jac` and `.impl.jac` files. Load when a source file grows past ~150 lines, or to separate a clean public-API surface from implementation.
---

A `.jac` file declares fields, enums, method signatures. A sibling `.impl.jac` (same basename, same directory) supplies the bodies via `impl <name>` blocks. The compiler auto-pairs them - no `import` between them. The `impl` keyword also works in a plain `.jac` file; the split is a discipline, not a syntax requirement.

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

Same code split: `shapes.jac` holds everything EXCEPT the two `impl` blocks; `shapes.impl.jac` holds them.

## Declaration → matching impl forms

| In `.jac` | In `.impl.jac` |
|---|---|
| `def fn_name;` | `impl fn_name { body }` |
| `def fn_name(args) -> T;` | `impl fn_name(args) -> T { body }` |
| `def Obj.method;` | `impl Obj.method { body }` |
| `def Obj.method(args) -> T;` | `impl Obj.method(args) -> T { body }` |
| `can event with NodeType entry;` | `impl Walker.event { body }` |
| `enum Color;` | `impl Color { RED = "r", GREEN = "g" }` |
| `enum Color: int;` (typed-base) | `impl Color { RED = 1, GREEN = 2 }` |
| `override def method;` (subclass) | `impl Subclass.method { body }` |
| `def method -> T abs;` (abstract) | (none on base - every subclass *should* `impl`; not compiler-enforced - see Rules) |

## Rules

- **Same basename, same directory.** `foo.jac` pairs with `foo.impl.jac` only if they sit together.
- **No `import` between the pair.** Compiler auto-pairs. Adding `import from foo.impl { ... }` is wrong.
- **Signature must match exactly.** `impl fn(x: int) -> str` paired with `def fn(y: str);` fails. Bare `impl fn { ... }` only matches bare `def fn;`.
- **`abs` = abstract.** `def area -> float abs;` on the base marks `area` as expected on every subclass. **This is not enforced** - a subclass with no `impl Subclass.area` still passes `jac check`, still instantiates, and calling the un-implemented method silently returns `None` (no error at compile, instantiation, or call). Treat `abs` as intent-signalling; make sure every subclass actually supplies its `impl`.
- **`override def` is required on subclass overrides.** Without it, `def play;` in a subclass is a NEW method that shadows - doesn't override.
- **Bodies in `.impl.jac` see the `.jac` file's imports.** Don't re-import inside the impl file.
