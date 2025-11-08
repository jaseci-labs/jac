Jac employs a familiar identifier system similar to Python and C-style languages while introducing specialized references essential for object-spatial programming. The naming system supports both traditional programming patterns and the unique requirements of computation moving through topological structures.

#### Standard Identifiers

Standard identifiers follow conventional rules: they must begin with an ASCII letter or underscore, followed by any combination of letters, digits, or underscores:

```jac
foo         # valid
_bar_42     # valid
my_variable # valid
3cats       # invalid – cannot start with digit
```

#### Keyword Escaping

When necessary, keywords can be used as identifiers by wrapping them with angle brackets:

```jac
<>with = 10;        # valid despite "with" being a keyword
print(<>with);
```

This escaping mechanism provides flexibility when interfacing with external systems or when identifier names conflict with Jac keywords.

#### Special References

Jac provides built-in special references that enable object-spatial programming patterns. These references have well-defined semantic meanings and cannot be reassigned:

| Reference | Context | Purpose |
|-----------|---------|---------|
| `self` | Archetype methods/abilities | Current instance reference |
| `here` | Walker abilities | Current node/edge location |
| `visitor` | Node/edge abilities | Visiting walker reference |
| `super` | Archetype methods | Parent archetype access |
| `root` | Any context | Root graph instance |
| `init`/`postinit` | Archetype bodies | Lifecycle hook references |

#### Explicit Notation for Special Variables

These keywords are reserved by the language and must appear exactly as shown.
They cannot be redefined or used for other identifiers.  Their explicit spelling
makes object-spatial code easier to read and prevents accidental shadowing of core
context references.

#### Object-Spatial Reference Usage

Special references enable the bidirectional interaction model central to object-spatial programming:

```jac
node DataNode {
    has name: str;
    has data: dict;

    can process with visitor entry {
        # 'self' refers to this node, 'visitor' to the walker
        print(f"Node {self.name} processing data for {visitor.id}");
        
        # Process data and update visitor state
        result = self.analyze_data();
        visitor.add_result(result);
    }
}

walker DataProcessor {
    has id: str;
    has results: list = [];

    can explore with entry {
        # 'self' refers to this walker, 'here' to current location
        print(f"Walker {self.id} arrived at {here.name}");
        
        # Continue traversal based on local context
        if (here.has_more_data()) {
            visit here.neighbors;
        }
    }
}
```

#### Name Resolution Hierarchy

Jac resolves names using a systematic hierarchy:

1. **Local scope**: Parameters, local variables, and `let` bindings
2. **Enclosing archetype scope**: Instance variables and methods
3. **Module scope**: Module-level definitions and globals
4. **Imported modules**: External module references
5. **Built-in references**: Special references and system functions

This resolution order ensures predictable behavior while supporting both lexical scoping and object-spatial context access.

#### Naming Conventions

Consistent naming enhances code clarity and supports Jac's static analysis capabilities:

- **Variables and functions**: `lower_snake_case`
- **Archetypes and enums**: `UpperCamelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Special references**: Reserved lowercase names

Descriptive naming is particularly important in object-spatial contexts where walkers, nodes, and edges interact dynamically, making clear semantic meaning essential for maintainable code.

The naming system provides the foundation for clear, expressive object-spatial programs where computation flows through well-defined topological structures with unambiguous reference semantics.
