"""Test fixture for inline suppression with # jac:ignore[CODE]."""

def greet(name: str) -> None {
    print("Hello, " + name);  # jac:ignore[E3012]
    print("This should still error");
}

def helper() -> None {
    print("suppressed by alias");  # jac:ignore[no-print]
    print("also suppressed multi");  # jac:ignore[E3012, W3001]
}
