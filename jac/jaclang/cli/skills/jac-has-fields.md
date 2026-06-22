---
name: jac-has-fields
description: Declaring typed fields on any stateful Jac archetype - types, defaults, ordering, postinit, static has, properties, inheritance defaults, access tags. Load before defining any type that carries state.
---

`has` declares typed fields on every Jac archetype (`obj`, `node`, `edge`, `walker` - only the keyword changes). Every field needs a type; defaults are optional. **All non-default fields must be declared before any defaulted field.** No `__init__` - the constructor is auto-generated from the `has` declarations; build instances with kwargs.

```jac
obj User {
    has name: str;                      # required - REQUIRED fields come first
    has age: int = 0;                   # defaulted fields come AFTER all required ones
    has tags: list[str] = [];           # typed list
    has manager: User | None = None;    # optional reference
    has a: int = 1, b: str = "x";       # multi-field form: one `has`, comma-separated
    static has population: int = 0;     # class-level, shared across instances
}

with entry {
    alice = User(name="alice");
    bob   = User(name="bob", age=30);
    alice.tags.append("admin");
    User.population += 2;               # static: access via the class
    print(alice.name, bob.age, User.population);
}
```

## Computed fields: `by postinit`

The sanctioned pattern for a field whose value derives from other fields. `by postinit` excludes it from the constructor; `def postinit` runs after the auto-generated init and must assign it:

```jac
obj Rectangle {
    has width: float,
        height: float;
    has area: float by postinit;

    def postinit {
        self.area = self.width * self.height;
    }
}

with entry {
    print(Rectangle(width=3.0, height=2.0).area);   # 6.0 - computed, not passed
}
```

(The `by postinit` line currently draws a spurious W1051 warning; `jac check` still passes.)

## Properties: `has x: T { getter; setter; }`

A `has` with an accessor block is a **property** - it never allocates storage. Declare backing storage as a separate `_`-prefixed field:

```jac
obj Account {
    has _balance: float = 0.0,
        balance: float {
            getter -> float { return self._balance; }
            setter(value: float) {
                if value < 0.0 { raise ValueError("negative"); }
                self._balance = value;
            }
        }
}
```

- Omit the `setter` → read-only; assignment fails at check time with **E1005**.
- `has x: T = value { ... }` (default + accessor block) is rejected: **E0080**. A `has` is a field OR a property, never both.
- An empty accessor block is **E0081**.
- Accessor bodies can be impl-separated: `impl Account.balance.getter -> float { ... }` - see `jac-impl-files`.

## Pitfalls

- **Non-default fields MUST come before default fields.** `has a: int = 0; has b: str;` fails with E2004 - the #1 has-ordering bug.
- **Parent defaults force child defaults.** If any inherited field has a default, every field in the subclass needs one too (dataclass constraint). `obj Animal { has name: str = "x"; }` + `obj Dog(Animal) { has breed: str; }` **passes `jac check` but crashes at runtime**: `TypeError: non-default argument 'breed' follows default argument`. Give `breed` a default.
- **All attributes must be `has`-declared.** `p.height = 175` on an object with no `has height` is the dynamic-attribute anti-pattern - it may run today but breaks portability (server/client/native) and will be rejected by future compilers. Declare every field upfront.
- **Backtick-escaped keywords don't work in `has`** (`has \`class: str;` = runtime SyntaxError) - pick a non-keyword name. See `jac-core-cheatsheet`.
- Access tags on members are *encapsulation*: `has:pub` anywhere, `has:protect` the declaring class **and its subclasses**, `has:priv` the declaring class only (`has:priv secret: str = "";`). This differs from top-level `def`/`glob`, where the same tags mean module/project visibility.
- `has name;` without a type is a parse error. Field access is attribute-style: `user.name`, NOT `user["name"]`.
- For optional references use `T | None` and guard `is None` - full type rules in `jac-types`.
- On **walkers**, `has` fields are also the spawn parameters (`root spawn W(field=...)`) - a required field with no default makes every spawn pass it (E1050 trap) - see `jac-walker-patterns`.

## See also

`jac-types` (annotations, unions, optionals) · `jac-impl-files` (property accessor impls) · `jac-node-edge-patterns` (fields on nodes/edges)
