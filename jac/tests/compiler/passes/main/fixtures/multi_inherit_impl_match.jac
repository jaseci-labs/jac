"""Fixture: impl matching with multi-inheritance classes used as base classes."""

obj ParentA { has value_a: int = 1; }
obj ParentB { has value_b: int = 2; }

obj MultiInheritanceClass(ParentA, ParentB) {
    static def my_static_method(x: int) -> int;
    def my_instance_method -> int;
}

# This creates a second defn reference for MultiInheritanceClass's symbol
obj ChildClass(MultiInheritanceClass) { }
