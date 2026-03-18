"""Impl: function bodies."""

impl greet_user(name: str, greeting: str, count: int) -> str {
    return f"{greeting}, {name}!" * count;
}
