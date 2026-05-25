"""Regression fixture: base class expressions must resolve in the enclosing scope.

When a child archetype has a member whose name shadows the base class identifier
(e.g. `class Child(Parent) { def Parent -> int {...} }`), name resolution inside
the base-classes list must skip past the class's own symbol table and look up
`Parent` in the enclosing (module) scope — Python semantics. Resolving in the
class's own scope finds the inner method first, producing MRO = [Child] and
making inherited members invisible.

The real-world manifestation: `datetime.datetime.fromisoformat(...)` used to
report E1030 because CPython's `class datetime(date)` has a method `def date()`
that shadowed the base class `date`.

This fixture should produce 0 errors. Before the fix it produced errors like
`E1030: Type "Child" has no attribute "greet"`.
"""

obj Parent {
    def greet -> str {
        return "hello from Parent";
    }
}

obj Child(Parent) {
    # Member whose name shadows the base class identifier.
    def Parent -> int {
        return 0;
    }
    # Inherited method must still type-check.
    def use_inherited -> str {
        return self.greet();
    }
}

glob c = Child(),
     s1: str = c.greet(),
     s2: str = c.use_inherited(),
     i: int = c.Parent();
