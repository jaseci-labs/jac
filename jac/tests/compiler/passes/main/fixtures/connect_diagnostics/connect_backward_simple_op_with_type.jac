"""Fixture: <++ used as if it accepts an edge type.

Expected diagnostic: E0028 — <++ does not take an edge type.
Correct form: n1 <+: Knows :<+ n2
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

    # Wrong: <++ does not accept an edge type — should emit E0028
    alice <++ Knows bob;
}
