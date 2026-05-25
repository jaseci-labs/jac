"""Circular type-only import: B references A as a type."""
import type from typed_import_circ_a { A }

obj B {
    has name: str = "B";
}

def use_a(a: A) -> B {
    return B();
}
