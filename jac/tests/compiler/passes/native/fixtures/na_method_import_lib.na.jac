"""Library module exporting a struct with methods.

Used by na_method_import.na.jac to test that _register_imported_archetype
forwards-declares imported archetype methods in method_funcs.
"""

obj:pub Counter {
    has value: int;

    def increment() -> int {
        self.value = self.value + 1;
        return self.value;
    }

    def add(n: int) -> int {
        self.value = self.value + n;
        return self.value;
    }
}

def:pub make_counter(start: int) -> Counter {
    return Counter(value=start);
}
