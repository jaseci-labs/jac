# Chapter 17: Type System Deep Dive

In this chapter, we'll explore Jac's advanced type system that provides powerful generic programming capabilities, type constraints, and graph-aware type checking. We'll build a generic data processing system that demonstrates type safety, constraints, and runtime validation through practical examples.

!!! info "What You'll Learn"
    - Advanced generic programming with the `any` type
    - Type constraints and validation patterns
    - Graph-aware type checking for nodes and edges
    - Building type-safe, reusable components
    - Runtime type validation and guards

---

## Advanced Type System Features

Jac's type system goes beyond basic types to provide powerful features that work seamlessly with Object-Spatial Programming. The `any` type enables flexible programming while maintaining type safety through runtime validation.

!!! success "Type System Benefits"
    - **Flexible Typing**: Use `any` for maximum flexibility when needed
    - **Runtime Safety**: Validate types at runtime with built-in guards
    - **Graph Integration**: Type safety extends to nodes, edges, and walkers
    - **Constraint Validation**: Enforce business rules through type checking

### Traditional vs Jac Type System

!!! example "Type System Comparison"
    === "Traditional Approach"
        ```python
        # python_generics.py - Complex generic setup
        from typing import TypeVar, Generic, List, Any, Union, Optional
        from abc import ABC, abstractmethod

        T = TypeVar('T')
        U = TypeVar('U')

        class Processable(ABC):
            @abstractmethod
            def process(self) -> str:
                pass

        class DataProcessor(Generic[T]):
            def __init__(self):
                self.items: List[T] = []

            def add(self, item: T) -> None:
                self.items.append(item)

            def process_all(self, func) -> List[Any]:
                return [func(item) for item in self.items]

            def find(self, predicate) -> Optional[T]:
                for item in self.items:
                    if predicate(item):
                        return item
                return None

        # Usage requires explicit type parameters
        processor: DataProcessor[int] = DataProcessor()
        processor.add(42)
        processor.add(24)
        ```

    === "Jac Type System"
        <div class="code-block">
        ```jac
        # data_processor.jac - Simple and flexible
        obj DataProcessor {
            has items: list[any] = [];

            def add(item: any) -> None {
                self.items.append(item);
            }

            def process_all(func: any) -> list[any] {
                return [func(item) for item in self.items];
            }

            def find(predicate: any) -> any | None {
                for item in self.items {
                    if predicate(item) {
                        return item;
                    }
                }
                return None;
            }

            def filter_by_type(target_type: any) -> list[any] {
                return [item for item in self.items if isinstance(item, target_type)];
            }
        }

        with entry {
            # Simple usage with type inference
            processor = DataProcessor();
            processor.add(42);
            processor.add("hello");
            processor.add(3.14);

            # Type-safe operations with runtime validation
            numbers = processor.filter_by_type(int);
            print(f"Numbers: {numbers}");
        }
        ```
        </div>

---

## Runtime Type Validation

Jac provides powerful runtime type checking capabilities that complement the flexible `any` type, enabling robust error handling and dynamic type validation.

### Type Guards and Validation

!!! example "Runtime Type Validation System"
    <div class="code-block">
    ```jac
    # type_validator.jac
    obj TypeValidator {
        has strict_mode: bool = False;

        """Check if value matches expected type."""
        def validate_type(value: any, expected_type: any) -> bool {
            if expected_type == int {
                return isinstance(value, int);
            } elif expected_type == str {
                return isinstance(value, str);
            } elif expected_type == float {
                return isinstance(value, float);
            } elif expected_type == list {
                return isinstance(value, list);
            } elif expected_type == dict {
                return isinstance(value, dict);
            }
            return True;  # Allow any for unknown types
        }

        """Safely cast value to target type."""
        def safe_cast(value: any, target_type: any) -> any | None {
            try {
                if target_type == int {
                    return int(value);
                } elif target_type == str {
                    return str(value);
                } elif target_type == float {
                    return float(value);
                } elif target_type == bool {
                    return bool(value);
                }
                return value;
            } except ValueError {
                if self.strict_mode {
                    raise ValueError(f"Cannot cast {value} to {target_type}");
                }
                return None;
            }
        }

        """Validate value is within specified range."""
        def validate_range(value: any, min_val: any = None, max_val: any = None) -> bool {
            if min_val is not None and value < min_val {
                return False;
            }
            if max_val is not None and value > max_val {
                return False;
            }
            return True;
        }
    }

    with entry {
        validator = TypeValidator(strict_mode=True);

        # Test type validation
        test_values = [42, "hello", 3.14, True, [1, 2, 3]];
        expected_types = [int, str, float, bool, list];

        for i in range(len(test_values)) {
            value = test_values[i];
            expected = expected_types[i];
            is_valid = validator.validate_type(value, expected);
            print(f"{value} is {expected}: {is_valid}");
        }

        # Test safe casting
        cast_result = validator.safe_cast("123", int);
        print(f"Cast '123' to int: {cast_result}");

        # Test range validation
        in_range = validator.validate_range(50, 0, 100);
        print(f"50 in range [0, 100]: {in_range}");
    }
    ```
    </div>

### Advanced Type Guards

!!! example "Complex Type Validation Patterns"
    <div class="code-block">
    ```jac
    # advanced_validator.jac
    obj SchemaValidator {
        has schema: dict[str, any] = {};

        """Define expected type for a field."""
        def set_field_type(field_name: str, field_type: any) -> None {
            self.schema[field_name] = field_type;
        }

        """Validate object against schema."""
        def validate_object(obj: any) -> dict[str, any] {
            results = {
                "valid": True,
                "errors": [],
                "field_results": {}
            };

            if not isinstance(obj, dict) {
                results["valid"] = False;
                results["errors"].append("Object must be a dictionary");
                return results;
            }

            for (field_name, expected_type) in self.schema.items() {
                if field_name not in obj {
                    results["valid"] = False;
                    results["errors"].append(f"Missing required field: {field_name}");
                    results["field_results"][field_name] = False;
                } else {
                    field_value = obj[field_name];
                    is_valid = self.validate_field(field_value, expected_type);
                    results["field_results"][field_name] = is_valid;
                    if not is_valid {
                        results["valid"] = False;
                        results["errors"].append(f"Invalid type for {field_name}: expected {expected_type}, got {type(field_value)}");
                    }
                }
            }

            return results;
        }

        """Validate individual field value."""
        def validate_field(value: any, expected_type: any) -> bool {
            if expected_type == "string" {
                return isinstance(value, str);
            } elif expected_type == "number" {
                return isinstance(value, (int, float));
            } elif expected_type == "boolean" {
                return isinstance(value, bool);
            } elif expected_type == "list" {
                return isinstance(value, list);
            } elif expected_type == "dict" {
                return isinstance(value, dict);
            }
            return True;
        }
    }

    with entry {
        # Create schema for user data
        user_validator = SchemaValidator();
        user_validator.set_field_type("name", "string");
        user_validator.set_field_type("age", "number");
        user_validator.set_field_type("email", "string");
        user_validator.set_field_type("active", "boolean");

        # Test valid user
        valid_user = {
            "name": "Alice",
            "age": 30,
            "email": "alice@example.com",
            "active": True
        };

        result = user_validator.validate_object(valid_user);
        print(f"Valid user validation: {result}");

        # Test invalid user
        invalid_user = {
            "name": "Bob",
            "age": "thirty",  # Wrong type
            "email": "bob@example.com"
            # Missing 'active' field
        };

        result = user_validator.validate_object(invalid_user);
        print(f"Invalid user validation: {result}");
    }
    ```
    </div>

---

## Graph-Aware Type Checking

Jac's type system extends to Object-Spatial Programming constructs, providing compile-time and runtime guarantees about graph structure and walker behavior.

### Node and Edge Type Safety

!!! example "Type-Safe Graph Operations"
    <div class="code-block">
    ```jac
    # typed_graph.jac
    node Person {
        has name: str;
        has age: int;

        def validate_person() -> bool {
            return len(self.name) > 0 and self.age >= 0;
        }
    }

    node Company {
        has company_name: str;
        has industry: str;

        def validate_company() -> bool {
            return len(self.company_name) > 0 and len(self.industry) > 0;
        }
    }

    edge WorksAt {
        has position: str;
        has salary: float;
        has start_date: str;

        def validate_employment() -> bool {
            return len(self.position) > 0 and self.salary > 0;
        }
    }

    edge FriendsWith {
        has since: str;
        has closeness: int;  # 1-10 scale

        def validate_friendship() -> bool {
            return self.closeness >= 1 and self.closeness <= 10;
        }
    }

    obj GraphValidator {
        has validation_errors: list[str] = [];

        """Validate any node type."""
        def validate_node(node: any) -> bool {
            self.validation_errors = [];

            if isinstance(node, Person) {
                if not node.validate_person() {
                    self.validation_errors.append(f"Invalid person: {node.name}");
                    return False;
                }
            } elif isinstance(node, Company) {
                if not node.validate_company() {
                    self.validation_errors.append(f"Invalid company: {node.company_name}");
                    return False;
                }
            } else {
                self.validation_errors.append(f"Unknown node type: {type(node)}");
                return False;
            }

            return True;
        }

        """Validate edge connection between nodes."""
        def validate_edge_connection(from_node: any, edge: any, to_node: any) -> bool {
            # Check if edge type is appropriate for node types
            if isinstance(edge, WorksAt) {
                # Person should work at Company
                if not (isinstance(from_node, Person) and isinstance(to_node, Company)) {
                    self.validation_errors.append("WorksAt edge must connect Person to Company");
                    return False;
                }
                return edge.validate_employment();
            } elif isinstance(edge, FriendsWith) {
                # Both nodes should be Person
                if not (isinstance(from_node, Person) and isinstance(to_node, Person)) {
                    self.validation_errors.append("FriendsWith edge must connect Person to Person");
                    return False;
                }
                return edge.validate_friendship();
            }

            self.validation_errors.append(f"Unknown edge type: {type(edge)}");
            return False;
        }
    }

    with entry {
        # Create graph elements
        alice = Person(name="Alice", age=30);
        bob = Person(name="Bob", age=25);
        tech_corp = Company(company_name="TechCorp", industry="Technology");

        # Create relationships
        works_edge = WorksAt(position="Developer", salary=75000.0, start_date="2023-01-15");
        friend_edge = FriendsWith(since="2020-01-01", closeness=8);

        # Validate graph elements
        validator = GraphValidator();

        # Validate nodes
        alice_valid = validator.validate_node(alice);
        print(f"Alice valid: {alice_valid}");

        # Validate edge connections
        work_connection_valid = validator.validate_edge_connection(alice, works_edge, tech_corp);
        print(f"Work connection valid: {work_connection_valid}");

        friend_connection_valid = validator.validate_edge_connection(alice, friend_edge, bob);
        print(f"Friend connection valid: {friend_connection_valid}");

        # Test invalid connection
        invalid_connection = validator.validate_edge_connection(alice, works_edge, bob);  # Wrong types
        print(f"Invalid connection valid: {invalid_connection}");
        print(f"Validation errors: {validator.validation_errors}");
    }
    ```
    </div>

### Walker Type Validation

!!! example "Type-Safe Walker Patterns"
    <div class="code-block">
    ```jac
    # typed_walkers.jac

    node Person {
        has name: str;
        has age: int;

        def validate_person() -> bool {
            return len(self.name) > 0 and self.age >= 0;
        }
    }

    node Company {
        has company_name: str;
        has industry: str;

        def validate_company() -> bool {
            return len(self.company_name) > 0 and len(self.industry) > 0;
        }
    }

    edge WorksAt {
        has position: str;
        has salary: float;
        has start_date: str;

        def validate_employment() -> bool {
            return len(self.position) > 0 and self.salary > 0;
        }
    }

    edge FriendsWith {
        has since: str;
        has closeness: int;  # 1-10 scale

        def validate_friendship() -> bool {
            return self.closeness >= 1 and self.closeness <= 10;
        }
    }

    walker PersonVisitor {
        has visited_count: int = 0;
        has person_names: list[str] = [];
        has validation_errors: list[str] = [];

        can visit_person with Person entry {
            # Type-safe person processing
            if self.validate_person_node(here) {
                self.visited_count += 1;
                self.person_names.append(here.name);
                print(f"Visited person: {here.name} (age {here.age})");

                # Continue to connected persons
                friends = [->:FriendsWith:->(`?Person)];
                if friends {
                    visit friends;
                }
            } else {
                print(f"Invalid person node encountered: {here.name}");
            }
        }

        can visit_company with Company entry {
            # Companies are not processed by PersonVisitor
            print(f"Skipping company: {here.company_name}");
        }

        """Validate person node before processing."""
        def validate_person_node(person: any) -> bool {
            if not isinstance(person, Person) {
                self.validation_errors.append(f"Expected Person, got {type(person)}");
                return False;
            }

            if not person.validate_person() {
                self.validation_errors.append(f"Invalid person data: {person.name}");
                return False;
            }

            return True;
        }
    }

    walker CompanyAnalyzer {
        has companies_visited: list[str] = [];
        has total_employees: int = 0;

        can analyze_company with Company entry {
            if self.validate_company_node(here) {
                self.companies_visited.append(here.company_name);
                print(f"Analyzing company: {here.company_name} in {here.industry}");

                # Count employees (people working at this company)
                employees = [<-:WorksAt:<-(`?Person)];
                employee_count = len(employees);
                self.total_employees += employee_count;

                print(f"  Employees: {employee_count}");
                for employee in employees {
                    print(f"    - {employee.name}");
                }
            }
        }

        """Validate company node before processing."""
        def validate_company_node(company: any) -> bool {
            if not isinstance(company, Company) {
                return False;
            }
            return company.validate_company();
        }
    }

    with entry {
        # Create network
        alice = root ++> Person(name="Alice", age=30);
        bob = root ++> Person(name="Bob", age=25);
        tech_corp = root ++> Company(company_name="TechCorp", industry="Technology");

        # Create connections
        alice[0] +>:WorksAt(position="Developer", salary=75000.0, start_date="2023-01-15"):+> tech_corp[0];
        bob[0] +>:WorksAt(position="Designer", salary=65000.0, start_date="2023-02-01"):+> tech_corp[0];
        alice[0] +>:FriendsWith(since="2020-01-01", closeness=8):+> bob[0];

        # Test type-safe walkers
        person_visitor = PersonVisitor();
        alice[0] spawn person_visitor;

        print(f"Person visitor results:");
        print(f"  Visited: {person_visitor.visited_count} people");
        print(f"  Names: {person_visitor.person_names}");

        company_analyzer = CompanyAnalyzer();
        tech_corp[0] spawn company_analyzer;

        print(f"Company analyzer results:");
        print(f"  Companies: {company_analyzer.companies_visited}");
        print(f"  Total employees: {company_analyzer.total_employees}");
    }
    ```
    </div>

---

## Building Type-Safe Components

Using Jac's flexible type system, we can build reusable components that are both type-safe and adaptable.

### Generic Data Structures

!!! example "Type-Safe Generic Collections"
    <div class="code-block">
    ```jac
    # generic_collections.jac
    obj SafeList {
        has items: list[any] = [];
        has item_type: any = None;
        has allow_mixed_types: bool = False;

        """Set type constraint for list items."""
        def set_type_constraint(expected_type: any) -> None {
            self.item_type = expected_type;
        }

        """Add item with type checking."""
        def add(item: any) -> bool {
            if self.item_type is not None and not self.allow_mixed_types {
                if not self.check_type(item, self.item_type) {
                    print(f"Type error: expected {self.item_type}, got {type(item)}");
                    return False;
                }
            }

            self.items.append(item);
            return True;
        }

        """Safely get item by index."""
        def get(index: int) -> any | None {
            if 0 <= index < len(self.items) {
                return self.items[index];
            }
            return None;
        }

        """Get all items of specific type."""
        def filter_by_type(target_type: any) -> list[any] {
            return [item for item in self.items if self.check_type(item, target_type)];
        }

        """Check if value matches expected type."""
        def check_type(value: any, expected_type: any) -> bool {
            if expected_type == int {
                return isinstance(value, int);
            } elif expected_type == str {
                return isinstance(value, str);
            } elif expected_type == float {
                return isinstance(value, float);
            } elif expected_type == bool {
                return isinstance(value, bool);
            } elif expected_type == list {
                return isinstance(value, list);
            } elif expected_type == dict {
                return isinstance(value, dict);
            }
            return True;
        }

        """Get summary of types in the list."""
        def get_type_summary() -> dict[str, int] {
            type_counts = {};
            for item in self.items {
                type_name = type(item).__name__;
                type_counts[type_name] = type_counts.get(type_name, 0) + 1;
            }
            return type_counts;
        }
    }

    with entry {
        # Create type-constrained list
        number_list = SafeList();
        number_list.set_type_constraint(int);

        # Add valid items
        success1 = number_list.add(42);
        success2 = number_list.add(24);
        success3 = number_list.add("hello");  # Should fail

        print(f"Added 42: {success1}");
        print(f"Added 24: {success2}");
        print(f"Added 'hello': {success3}");

        # Create mixed-type list
        mixed_list = SafeList(allow_mixed_types=True);
        mixed_list.add(42);
        mixed_list.add("hello");
        mixed_list.add(3.14);
        mixed_list.add(True);

        print(f"Mixed list type summary: {mixed_list.get_type_summary()}");

        # Filter by type
        numbers = mixed_list.filter_by_type(int);
        strings = mixed_list.filter_by_type(str);

        print(f"Numbers: {numbers}");
        print(f"Strings: {strings}");
    }
    ```
    </div>

---

## Best Practices

!!! summary "Type System Guidelines"
    - **Use `any` strategically**: Apply `any` type for maximum flexibility while implementing runtime validation
    - **Validate at boundaries**: Check types when data enters your system from external sources
    - **Leverage runtime checks**: Use isinstance() and custom validation functions for type safety
    - **Design for flexibility**: Build components that can handle multiple types when appropriate
    - **Document type expectations**: Make type requirements clear in function and method documentation
    - **Test with multiple types**: Verify your code works correctly with different type combinations

## Key Takeaways

!!! summary "What We've Learned"
    **Advanced Type Features:**

    - **Flexible typing**: Use `any` type for maximum flexibility when needed
    - **Runtime validation**: Dynamic type checking complements static analysis
    - **Graph-aware types**: Compile-time safety for spatial programming constructs
    - **Type guards**: Runtime validation patterns for dynamic typing

    **Practical Applications:**

    - **Reusable components**: Build libraries that work with multiple data types
    - **Safe graph operations**: Prevent type errors in node and edge relationships
    - **Data validation**: Robust input validation with clear error messages
    - **Performance optimization**: Type information enables better optimization

    **Development Benefits:**

    - **Early error detection**: Catch type mismatches through validation
    - **Better documentation**: Types and validation serve as executable documentation
    - **IDE support**: Enhanced development experience with type information
    - **Refactoring safety**: Type system helps prevent breaking changes

    **Advanced Features:**

    - **Schema validation**: Complex object validation with custom rules
    - **Type constraints**: Enforce business rules through type checking
    - **Generic patterns**: Type-safe graph traversal and processing
    - **Protocol support**: Interface-based programming with validation

!!! tip "Try It Yourself"
    Master the type system by building:

    - A generic data processing pipeline with runtime validation
    - Type-safe graph algorithms with proper node/edge validation
    - Runtime validation systems for API endpoints
    - Generic walker patterns for different graph structures

    Remember: Jac's type system provides flexibility through `any` while enabling powerful runtime validation!

---

*Ready to learn about testing and debugging? Continue to [Chapter 18: Testing and Debugging](chapter_17.md)!*
