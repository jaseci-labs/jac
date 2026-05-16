---
name: jac-has-fields
description: Declaring typed fields on any stateful Jac archetype - types, defaults, ordering, optional references. Load before defining any type that carries state.
---

`has` declares typed fields on every Jac archetype. Every field needs a type; defaults are optional. **All non-default fields must be declared before any defaulted field.** No `__init__` - build instances with constructor kwargs.

```jac
obj User {
    has name: str;                      # required - REQUIRED fields come first
    has age: int = 0;                   # defaulted fields come AFTER all required ones
    has tags: list[str] = [];           # typed list
    has meta: dict[str, str] = {};      # typed dict
    has manager: User | None = None;    # optional reference
}

with entry {
    alice = User(name="alice");
    bob   = User(name="bob", age=30);
    alice.tags.append("admin");
    print(alice.name, alice.age, alice.tags);
}
```

Same `has` syntax on `node`, `edge`, `walker` - only the archetype keyword changes.

## Pitfalls

- Field access is attribute-style: `user.name`, NOT `user["name"]`.
- For optional references use `T | None` - see `jac-types` for the full type-system rules.
- `has name;` is invalid - always `has name: type;`. Every field needs an explicit type.
- **Non-default fields MUST come before default fields.** `has a: int = 0; has b: str;` fails with E2004. Reorder so every required field appears first - this is the #1 has-ordering bug, and the compiler error message is clear but the fix is easy to miss if you don't know the rule.
