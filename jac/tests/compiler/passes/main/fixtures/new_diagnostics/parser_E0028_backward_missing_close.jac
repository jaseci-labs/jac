"""Fixture for E0028: backward typed connection (<+: EdgeType) missing :<+ closer."""
node Person { has name: str; }
edge Knows { has since: int = 0; }
with entry {
    alice = Person(name="alice");
    bob = Person(name="bob");
    alice <+: Knows bob;  # <-- Error E0028
}
