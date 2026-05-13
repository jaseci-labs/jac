"""Fixture for E0027: forward typed connection (+>: EdgeType) missing :+> closer."""
node Person { has name: str; }
edge Knows { has since: int = 0; }
with entry {
    alice = Person(name="alice");
    bob = Person(name="bob");
    alice +>: Knows bob;  # <-- Error E0027
}
