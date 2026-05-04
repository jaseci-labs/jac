"""Fixture: forward typed connection with missing :+> closer.
Expected diagnostic: E0027 on the malformed connection line.
"""
node Person {
    has name: str;
}
edge Knows {
    has since: int = 0;
}
with entry {
    alice = Person(name="alice");
    bob = Person(name="bob");
    # Missing :+> — should emit E0027
    alice +>: Knows bob;
}
