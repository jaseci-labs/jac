Archetypes represent Jac's extension of traditional object-oriented programming classes, providing specialized constructs that enable object-spatial programming. Each archetype type serves a distinct role in building topological computational systems where data and computation are distributed across graph structures.

#### Archetype Types

Jac defines five archetype categories that form the foundation of object-spatial programming:

**Object (`obj`)**: Standard object archetypes that represents tradtional OOP class semantics. Objects serve as the base type from which nodes, walkers, and edges inherit, ensuring compatibility with object-spatial programming patterns.

**Node (`node`)**: Specialized archetypes that represent discrete locations within topological structures. Nodes can store data, host computational abilities, and connect to other nodes through edges, forming the spatial foundation for graph-based computation.

**Walker (`walker`)**: Mobile computational entities that traverse node-edge structures, carrying algorithmic behaviors and state throughout the topological space. Walkers embody the "computation moving to data" paradigm central to object-spatial programming.

**Edge (`edge`)**: First-class relationship archetypes that connect nodes while providing their own computational capabilities. Edges represent both connectivity and transition-specific behaviors within the graph structure.

**Class (`class`)**: Python-compatible class archetypes that faithfully follow Python's class syntax and semantics. Unlike other archetypes, classes require explicit `self` parameters in methods and do not support the `has` keyword for property declarations. They provide full compatibility with Python's object-oriented programming model.

#### Implementation Details

From an implementation standpoint, the four object-spatial archetypes (`obj`, `node`, `walker`, `edge`) behave similarly to Python dataclasses. Their constructor semantics and initialization rules mirror the automated constructors that Python generates for dataclasses, providing automatic initialization of `has` variables and proper handling of inheritance hierarchies.

#### Class vs Object-Spatial Archetypes

The `class` archetype provides Python-compatible class definitions, while the semantics for other archetypes are inspired by dataclass-like behavior:

```jac
# Python-compatible class archetype
class PythonStyleClass {
    def init(self: PythonStyleClass, value: int) {
        self.value = value;
    }
    
    def increment(self, amount: int) {
        self.value += amount;
        return self.value;
    }
}

# Jac's obj with automated constructor semantics
obj DataSpatialObject {
    has value: int;  # Automatically included in constructor
    
    can increment(amount: int) {
        self.value += amount;
        return self.value;
    }
}
```

Note that `class` archetypes require explicit `self` parameters and manual constructor definition, while object-spatial archetypes automatically generate constructors based on `has` declarations.

#### Constructor Rules and Has Variables

Data spatial archetypes (`obj`, `node`, `walker`, `edge`) automatically generate constructors based on their `has` variable declarations, following rules similar to Python dataclasses:

```jac
obj Person {
    has name: str;
    has age: int = 0;  # Default value
    has id: str by postinit;
    
    can postinit {
        # Called after automatic initialization
        self.id = f"{self.name}_{self.age}";
    }
}

# Constructor automatically accepts name and age parameters
person = Person(name="Alice", age=30);
# After construction, postinit runs to set id = "Alice_30"
```

**Constructor Generation Rules:**
- All `has` variables without default values become required constructor parameters
- Variables with default values become optional parameters
- Parameters are accepted in declaration order
- The `postinit` method runs after all `has` variables are initialized

**Post-initialization Hook:**
The `postinit` method mirrors Python's `__post_init__` semantics:
- Executes automatically after the generated constructor completes
- Has access to all initialized `has` variables
- Useful for derived attributes, validation, or complex initialization logic
- Cannot modify the constructor signature

```jac
node DataNode {
    has raw_data: list;
    has processed: bool = False;
    has stats: dict by postinit;
    
    can postinit {
        # Compute derived data after construction
        self.stats = {
            "count": len(self.raw_data),
            "types": set(type(x) for x in self.raw_data)
        };
        self.processed = True;
    }
}
```

#### Inheritance and Composition

Archetypes support multiple inheritance, enabling complex type hierarchies that reflect real-world relationships:

```jac
obj Animal;
obj Domesticated;

node Pet(Animal, Domesticated) {
    has name: str;
    has species: str;
}

walker Caretaker(Person) {
    can feed with Pet entry {
        print(f"Feeding {here.name} the {here.species}");
    }
}
```

The inheritance syntax `(ParentType1, ParentType2)` allows archetypes to combine behaviors from multiple sources, supporting rich compositional patterns.

#### Decorators and Metaprogramming

Decorators provide metaprogramming capabilities that enhance archetype behavior without modifying core definitions:

```jac
@print_base_classes
node EnhancedPet(Animal, Domesticated) {
    has enhanced_features: list;
}

@performance_monitor
walker OptimizedProcessor {
    can process with entry {
        # Processing logic with automatic performance tracking
        analyze_data(here.data);
    }
}
```

Decorators enable cross-cutting concerns like logging, performance monitoring, and validation to be applied declaratively across archetype definitions.

#### Access Control

Archetypes support access modifiers that control visibility and encapsulation:

```jac
node :pub DataNode {
    has :priv internal_state: dict;
    has :pub public_data: any;
    
    can :protect process_internal with visitor entry {
        # Protected processing method
        self.internal_state.update(visitor.get_updates());
    }
}
```

Access modifiers (`:pub`, `:priv`, `:protect`) enable proper encapsulation while supporting the collaborative nature of object-spatial computation.

#### Object-Spatial Integration

Archetypes work together to create complete object-spatial systems:

```jac
node DataSource {
    has data: list;
    
    can provide_data with walker entry {
        visitor.receive_data(self.data);
    }
}

edge DataFlow(DataSource, DataProcessor) {
    can transfer with walker entry {
        # Edge-specific transfer logic
        transformed_data = self.transform(visitor.data);
        visitor.update_data(transformed_data);
    }
}

walker DataCollector {
    has collected: list = [];
    
    can collect with DataSource entry {
        here.provide_data();
        visit [-->];  # Continue to connected nodes
    }
}
```

This integration enables sophisticated graph-based algorithms where computation flows naturally through topological structures, with each archetype type contributing its specialized capabilities to the overall system behavior.

Archetypes provide the foundational abstractions that make object-spatial programming both expressive and maintainable, enabling developers to model complex systems as interconnected computational topologies.

#### Async Walker

Async walkers extend the walker archetype with asynchronous capabilities:

```jac
import time;
import asyncio;
import from typing {Coroutine}

node A {
    has val: int;
}

async walker W {
    has num: int;

    async can do1 with A entry {
        print("A Entry action ", here.val);
        visit [here-->];
    }
}

with entry {
    root ++> (a1 := A(1)) ++> [a2 := A(2), a3 := A(3), a4 := A(4)];
    w1 = W(8);
    async def foo(w:W, a:A)-> None {
        print("Let's start the task");
        x = w spawn a;
        print("It is Coroutine task", isinstance(x, Coroutine));
        await x;
        print("Coroutine task is completed");
    }
    asyncio.run(foo(w1,a1));
}
```

Async walkers provide significant advantages for modern object-spatial applications by enabling concurrent execution where multiple async walkers can traverse different graph regions simultaneously, improving overall system throughput. They excel at handling non-blocking I/O operations, ensuring that network requests, file operations, and database queries don't block the traversal of other graph paths. This seamless asyncio integration provides full compatibility with Python's rich async ecosystem, allowing developers to leverage existing async libraries and frameworks within their object-spatial programs. The asynchronous nature also leads to superior resource efficiency through better utilization of system resources during I/O operations, as the system can continue processing other graph nodes while waiting for slow operations to complete.
