"""Circular type-only import: A references B as a type."""
import type from typed_import_circ_b { B }

obj A {
    has name: str = "A";
}

def use_b(b: B) -> A {
    return A();
}
