Archetype bodies define the internal structure and behavior of Jac's specialized class constructs. These bodies contain member declarations, abilities, and implementation details that enable both traditional object-oriented programming and object-spatial computation patterns.

#### Member Declaration Syntax

Archetype members are declared using the `has` keyword with mandatory type annotations:

```jac
obj Vehicle {
    has make: str;
    has model: str;
    has year: int;
    static has wheels: int = 4;
}
```

The `has` keyword establishes instance variables with explicit type constraints, while `static has` creates class-level variables shared across all instances.

#### Instance and Static Members

**Instance Members**: Declared with `has`, these variables belong to individual archetype instances and maintain separate state for each object.

**Static Members**: Declared with `static has`, these variables belong to the archetype class itself and are shared across all instances, providing class-level data storage.

#### Ability Definitions

Abilities within archetype bodies define both traditional methods and object-spatial behaviors:

```jac
obj DataProcessor {
    has data: list;
    
    can process_data(self) -> dict {
        # Traditional method implementation
        return {"processed": len(self.data), "status": "complete"};
    }
    
    can validate with entry {
        # Data spatial ability triggered by events
        if (not self.data) {
            raise ValueError("No data to process");
        }
    }
}
```

#### Access Control Modifiers

Archetype bodies support access control for encapsulation:

```jac
obj SecureContainer {
    has :pub public_data: str;
    has :priv private_data: str;
    has :protect protected_data: str;
    
    can :pub get_public_info(self) -> str {
        return self.public_data;
    }
    
    can :priv internal_process(self) {
        # Private method for internal use
        self.protected_data = "processed";
    }
}
```

Access modifiers (`:pub`, `:priv`, `:protect`) control visibility and access patterns across module boundaries.

#### Object-Spatial Archetype Bodies

Data spatial archetypes include specialized members and abilities:

```jac
node DataNode {
    has data: dict;
    has processed: bool = false;
    has connections: int = 0;
    
    can process_incoming with visitor entry {
        # Triggered when walker enters this node
        print(f"Processing visitor {visitor.id} at node {self.id}");
        self.processed = true;
        visitor.record_visit(self);
    }
    
    can cleanup with visitor exit {
        # Triggered when walker leaves this node
        self.connections += 1;
        print(f"Visitor departed, total connections: {self.connections}");
    }
}

walker DataCollector {
    has collected: list = [];
    has visit_count: int = 0;
    
    can collect with DataNode entry {
        # Triggered when entering DataNode instances
        self.collected.append(here.data);
        self.visit_count += 1;
    }
    
    can record_visit(self, node: DataNode) {
        # Traditional method callable by nodes
        print(f"Recorded visit to node {node.id}");
    }
}

edge DataFlow(DataNode, DataNode) {
    has flow_rate: float;
    has capacity: int;
    
    can regulate_flow with visitor entry {
        # Triggered when walker traverses this edge
        if (visitor.data_size > self.capacity) {
            visitor.compress_data();
        }
    }
}
```

#### Constructor Patterns

Archetype bodies can include initialization logic:

```jac
obj ConfigurableProcessor {
    has config: dict;
    has initialized: bool = false;
    
    can init(self, config_data: dict) {
        # Constructor-like initialization
        self.config = config_data;
        self.initialized = true;
        self.validate_config();
    }
    
    can validate_config(self) {
        # Private validation method
        required_keys = ["input_format", "output_format"];
        for key in required_keys {
            if (key not in self.config) {
                raise ValueError(f"Missing required config: {key}");
            }
        }
    }
}
```

#### Method Overriding and Inheritance

Archetype bodies support inheritance patterns:

```jac
obj BaseProcessor {
    has name: str;
    
    can process(self, data: any) -> any {
        # Base implementation
        return data;
    }
    
    can get_info(self) -> str {
        return f"Processor: {self.name}";
    }
}

obj AdvancedProcessor(BaseProcessor) {
    has advanced_features: list;
    
    can process(self, data: any) -> any {
        # Override base implementation
        enhanced_data = self.enhance_data(data);
        return super().process(enhanced_data);
    }
    
    can enhance_data(self, data: any) -> any {
        # Additional processing logic
        return {"enhanced": data, "features": self.advanced_features};
    }
}
```

#### Integration with Implementation Blocks

Archetype bodies can be separated from their implementations:

```jac
obj Calculator {
    has precision: int = 2;
    
    # Method declarations
    can add(self, a: float, b: float) -> float;
    can multiply(self, a: float, b: float) -> float;
}

impl Calculator {
    can add(self, a: float, b: float) -> float {
        result = a + b;
        return round(result, self.precision);
    }
    
    can multiply(self, a: float, b: float) -> float {
        result = a * b;
        return round(result, self.precision);
    }
}
```

#### Documentation and Metadata

Archetype bodies can include documentation strings:

```jac
obj DocumentedClass {
    """
    A well-documented archetype that demonstrates
    proper documentation practices in Jac.
    """
    
    has value: int;
    
    can get_value(self) -> int {
        """Returns the current value."""
        return self.value;
    }
    
    can set_value(self, new_value: int) {
        """Sets a new value with validation."""
        if (new_value < 0) {
            raise ValueError("Value must be non-negative");
        }
        self.value = new_value;
    }
}
```

Archetype bodies provide the structural foundation for Jac's object-oriented and object-spatial programming capabilities, enabling developers to create sophisticated, well-encapsulated components that support both traditional programming patterns and innovative topological computation models.
