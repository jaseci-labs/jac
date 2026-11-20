"""Test exception variable registration in symbol table."""

with entry {
    try {
        raise ValueError("test");
    } except ValueError as e {
        print(e);
    }
}
