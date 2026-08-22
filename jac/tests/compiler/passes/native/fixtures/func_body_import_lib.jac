"""Sibling module imported from inside a function body by func_body_import.jac."""

obj:pub Counter {
    has value: int;

    def increment -> int {
        self.value = self.value + 1;
        return self.value;
    }
}

def:pub make_counter(start: int) -> Counter {
    return Counter(value=start);
}

def:pub bump(c: Counter) -> int {
    return c.increment();
}
