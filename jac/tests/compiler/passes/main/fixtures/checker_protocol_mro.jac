"""Tests for MRO-based protocol checking with built-in types.

This fixture verifies that protocol conformance checking correctly uses
Method Resolution Order (MRO) to look up members, and provides helpful
error messages explaining which protocol members are missing.
"""

obj HasLength {
    """A class that implements the Sized protocol via __len__."""
    has items: list[int] = [];

    def __len__()  -> int {
        return len(self.items);
    }
}

obj MissingLen {
    """A class that does NOT implement __len__."""
    has value: int = 0;
}

with entry {
    # Test 1: Built-in types with len()
    lst: list[int] = [1, 2, 3];
    len(lst);  # <-- Ok: list has __len__

    s: str = "hello";
    len(s);  # <-- Ok: str has __len__

    # Test 2: Custom class that implements __len__
    has_len = HasLength(items=[1, 2, 3]);
    len(has_len);  # <-- Ok: HasLength has __len__

    # Test 3: Built-in type without __len__ (should show helpful error)
    i: int = 42;
    len(i);  # <-- Error: int is missing __len__

    # Test 4: Custom class without __len__ (should show helpful error)
    missing = MissingLen();
    len(missing);  # <-- Error: MissingLen is missing __len__
}
