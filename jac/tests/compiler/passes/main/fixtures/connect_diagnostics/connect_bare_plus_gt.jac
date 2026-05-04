"""Fixture: bare +> used instead of ++>.
Expected diagnostic: E0036 — +> is not a valid connection operator.
Correct form: n1 ++> n2
"""
node Person {
    has name: str;
}
with entry {
    alice = Person(name="alice");
    bob = Person(name="bob");
    # Wrong: +> is not a valid operator — should emit E0036
    alice +> bob;
}
