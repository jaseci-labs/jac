"""Test fixture for __init__ and __post_init__ to init/postinit conversion.

This file contains Python-style __init__ and __post_init__ methods
that should be converted to Jac's init and postinit keywords.
"""

# Basic class with __init__ and comments
class Person {
    has name: str;
    has age: int;

    # Constructor comment before __init__
    """Initialize a Person with name and age."""
    def __init__(self: Person, name: str, age: int) -> None {
        # Set the name field
        self.name = name;
        self.age = age;  # inline comment for age
    }

    def greet(self: Person) -> str {
        return f"Hello, I'm {self.name}";
    }
}

# Employee class extending Person
class Employee(Person) {
    has employee_id: str;
    has department: str;

    # Employee constructor with super call
    """Initialize Employee with additional employee_id."""
    def __init__(self: Employee, name: str, age: int, employee_id: str) -> None {
        super().__init__(name, age);  # Call parent constructor
        self.employee_id = employee_id;
    }

    # Post-initialization hook
    """Set default department after initialization."""
    def __post_init__(self: Employee) -> None {
        # Default department assignment
        self.department = "Unassigned";
    }
}

# DataClass with only __post_init__
class DataClass {
    has x: int;
    has y: int;
    has computed: int;

    # Compute derived value after init
    """Calculate computed field from x and y."""
    def __post_init__(self: DataClass) -> None {
        self.computed = self.x + self.y;  # sum of x and y
    }
}

# Class with multiple comments around __init__
class CommentedClass {
    has value: int;

    # First comment before init
    # Second comment before init
    """Multi-line docstring
    for the init method."""
    def __init__(self: CommentedClass, value: int) -> None {
        # Comment inside init body
        self.value = value;
        # Another comment at end
    }
}
