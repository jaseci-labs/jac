"""Fixture for E2036: Duplicate definition in same scope."""

def foo() -> None { }
def foo() -> int { return 1; }  # <-- Error E2036: duplicate 'foo'

obj Bar { }
obj Bar { }  # <-- Error E2036: duplicate 'Bar'
