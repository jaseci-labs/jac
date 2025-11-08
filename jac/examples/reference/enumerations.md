Jac provides native enumeration support through the `enum` construct, offering ordered sets of named constants with integrated access control and implementation capabilities. Enumerations behave similarly to Python's `enum.Enum` while supporting Jac's archetype system and object-spatial programming features.

#### Basic Enumeration Declaration

```jac
enum Color {
    RED   = 1,
    GREEN = 2,
    BLUE,          # implicit value → 3
}
```

Enumeration values automatically increment from the previous value when omitted. Trailing commas are permitted, and enum names follow standard identifier rules consistent with other Jac archetypes.

#### Access Control

Enumerations support access modifiers to control visibility across module boundaries:

```jac
enum :protect Role {
    ADMIN = "admin",
    USER  = "user",
}

enum :pub Status {
    ACTIVE,
    INACTIVE,
    PENDING
}
```

Access modifiers (`:priv`, `:protect`, `:pub`) determine whether enumerations can be accessed from external modules, enabling proper encapsulation of enumerated constants.

#### Member Properties

Enumeration members expose standard properties for introspection:

```jac
print(Color.RED.name);    # "RED"
print(Color.RED.value);   # 1
```

These properties provide runtime access to both the symbolic name and underlying value of enumeration members, supporting dynamic enumeration processing.

#### Implementation Blocks

Enumerations can include additional behavior through implementation blocks, separating declaration from logic:

```jac
enum Day;

impl Day {
    MON = 1,
    TUE = 2,
    WED = 3,
    THU = 4,
    FRI = 5,
    SAT = 6,
    SUN = 7,

    def is_weekend(self) -> bool {
        return self in [Day.SAT, Day.SUN];
    }
    
    def next_day(self) -> Day {
        return Day((self.value % 7) + 1);
    }
}
```

Implementation blocks enable enumerations to contain methods and computed properties while maintaining clean separation between constant definitions and behavioral logic.

#### Integration with Decorators

Enumerations support Python decorators for additional functionality:

```jac
import from enum { unique };

@unique
enum Priority {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
}
```

The `@unique` decorator ensures all enumeration values are distinct, preventing accidental duplicate assignments.

#### Usage in Object-Spatial Contexts

Enumerations integrate seamlessly with object-spatial programming constructs:

```jac
enum NodeType {
    DATA,
    PROCESSING,
    STORAGE
}

node TypedNode {
    has node_type: NodeType;
    
    can process with visitor entry {
        if (self.node_type == NodeType.PROCESSING) {
            # Perform processing logic
            result = process_data(visitor.data);
            visitor.set_result(result);
        }
    }
}
```

Enumerations provide type-safe constants that enhance code clarity and maintainability in both traditional programming contexts and object-spatial graph operations.
