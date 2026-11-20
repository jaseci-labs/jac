"""Method dispatch through a vtable in a wasm module.

`Pool` declares a method a subclass overrides, so both carry a vtable, and
`measure` dispatches through a reference typed as the base. The vtable is data
holding function-table indices, so this runs only if the wasm linker applies
the data section's relocations.
"""

obj Pool {
    has items: list[int] = [];

    def size -> int {
        return len(self.items);
    }
}

obj Scaled(Pool) {
    has factor: int = 10;

    def size -> int {
        return len(self.items) * self.factor;
    }
}

def measure(p: &Pool) -> int {
    return p.size();
}

def compute(n: int) -> int {
    plain = Pool();
    scaled = Scaled();
    for i in range(n) {
        plain.items.append(i);
        scaled.items.append(i);
    }
    return measure(&plain) * 1000 + measure(&scaled);
}
