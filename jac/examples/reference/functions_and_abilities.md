Jac provides two complementary approaches to defining executable code: traditional functions using `def` and object-spatial abilities using `can`. This dual system supports both conventional programming patterns and the unique requirements of computation moving through topological structures.

#### Omission of Gratuitous `self`

Unlike Python, Jac methods of `obj`, `node`, `edge`, and `walker` do not require a `self` parameter unless it is
actually used.  Instance methods implicitly receive the current object, reducing
boilerplate and keeping signatures focused on relevant parameters.

#### Function Definitions

Traditional functions use the `def` keyword with mandatory type annotations:

```jac
def calculate_distance(x1: float, y1: float, x2: float, y2: float) -> float {
    return ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5;
}
```

Functions provide explicit parameter passing and return value semantics, making them suitable for stateless computations and utility operations.

#### Abilities

Abilities represent Jac's distinctive approach to defining behaviors that respond to object-spatial events:

```jac
walker PathFinder {
    can explore with node entry {
        # Ability triggered when walker enters any node
        print(f"Exploring node: {here.name}");
        visit [-->];  # Continue to connected nodes
    }
    
    can process with DataNode exit {
        # Ability triggered when leaving DataNode instances
        print(f"Finished processing {here.data}");
    }
}
```

Abilities execute implicitly based on spatial events rather than explicit invocation, embodying the object-spatial programming paradigm.

#### Access Control

Both functions and abilities support access modifiers for encapsulation:

```jac
obj Calculator {
    def :pub add(a: float, b: float) -> float {
        return a + b;
    }
    
    def :priv internal_compute(data: list) -> float {
        return sum(data) / len(data);
    }
    
    can :protect validate with entry {
        # Protected ability for internal validation
        if (not self.is_valid()) {
            raise ValueError("Invalid calculator state");
        }
    }
}
```

#### Static Methods

Static methods operate at the class level without requiring instance context:

```jac
obj MathUtils {
    static def multiply(a: float, b: float) -> float {
        return a * b;
    }
    
    static def factorial(n: int) -> int {
        return 1 if n <= 1 else n * MathUtils.factorial(n - 1);
    }
}
```

#### Abstract Declarations

Abstract methods define interfaces that must be implemented by subclasses:

```jac
obj Shape {
    def area() -> float abs;
    def perimeter() -> float abs;
}

obj Rectangle(Shape) {
    has width: float;
    has height: float;
    
    def area() -> float {
        return self.width * self.height;
    }
    
    def perimeter() -> float {
        return 2 * (self.width + self.height);
    }
}
```

#### Implementation Separation

Jac enables separation of declarations from implementations using `impl` blocks:

```jac
obj DataProcessor {
    def process_data(data: list) -> dict;
}

impl DataProcessor {
    def process_data(data: list) -> dict {
        return {
            "count": len(data),
            "sum": sum(data),
            "average": sum(data) / len(data)
        };
    }
}
```

#### Object-Spatial Integration

Abilities integrate seamlessly with object-spatial constructs, enabling sophisticated graph algorithms:

```jac
node DataNode {
    has data: dict;
    has processed: bool = false;
    
    can validate with visitor entry {
        # Node ability triggered by walker visits
        if (not self.data) {
            visitor.report_error(f"Empty data at {self.id}");
        }
    }
    
    can mark_complete with visitor exit {
        # Mark processing complete when walker leaves
        self.processed = true;
    }
}

walker DataValidator {
    has errors: list = [];
    
    can report_error(message: str) {
        self.errors.append(message);
    }
    
    can validate_graph with entry {
        # Start validation process
        visit [-->*];  # Visit all reachable nodes
    }
}
```

#### Parameter Patterns

Functions and abilities support flexible parameter patterns:

```jac
def flexible_function(required: int, optional: str = "default", *args: tuple, **kwargs: dict) -> any {
    return {
        "required": required,
        "optional": optional,
        "args": args,
        "kwargs": kwargs
    };
}
```

#### Asynchronous Operations

Both functions and abilities support asynchronous execution:

```jac
async def fetch_data(url: str) -> dict {
    # Asynchronous data fetching
    response = await http_client.get(url);
    return response.json();
}

walker AsyncProcessor {
    async can process with entry {
        # Asynchronous ability execution
        data = await fetch_data(here.data_url);
        here.update_data(data);
    }
}
```

Functions and abilities together provide a comprehensive system for organizing computational logic that supports both traditional programming patterns and the innovative object-spatial paradigm where computation flows through topological structures.
