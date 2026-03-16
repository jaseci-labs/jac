"""Library for imported-archetype-methods fix test (FIX 3a).

Before the fix, method_funcs was only populated for archetypes defined in
the current module.  Methods on imported archetypes were never registered,
so calls like `c.increment()` were silently dropped from the IR.
"""

obj:pub Counter {
    has value: int;

    """Increment value by 1 and return the new value."""
    def:pub increment() -> int {
        self.value = self.value + 1;
        return self.value;
    }

    """Add delta to value and return the new value."""
    def:pub add_delta(delta: int) -> int {
        self.value = self.value + delta;
        return self.value;
    }
}

def:pub make_counter() -> Counter {
    return Counter(value=0);
}

def:pub make_counter_at(start: int) -> Counter {
    return Counter(value=start);
}
