"""Archetype bodies: Member statements (has, static, methods, nested types)."""

"""This is a module-level docstring"""
obj Vehicle {
    """Member docstring"""
    has name: str,
        year: int;

    # Static members
    static has count: int = 0;
    # Access modifiers
    has:pub public_id: str = "V123";
    has:priv private_data: int = 0;
    # Has with postinit initialization
    has config: dict by postinit;

    def postinit {
        self.config = {"active": True};
        Vehicle.count += 1;
    }

    # Instance methods
    def display -> str {
        return f"{self.year} {self.name}";
    }

    # Static methods
    static def get_count -> int {
        return Vehicle.count;
    }

    # Nested class
    class Part {
        has part_name: str;
    }

    # Inline Python
    ::py::
    def py_method(self):
        return "Python code"
    ::py::

}

glob v1 = Vehicle(name="Car", year=2020),
     v2 = Vehicle(name="Truck", year=2021);

with entry {
    print(v1.display(), v2.display(), Vehicle.get_count());
}
