"""Fixture for E1182: Dict key type is not hashable."""

with entry {
    good: dict[str, int] = {"a": 1};    # <-- Ok: str is hashable
    bad: dict[list, int] = {};           # <-- Error E1182: list is not hashable
}
