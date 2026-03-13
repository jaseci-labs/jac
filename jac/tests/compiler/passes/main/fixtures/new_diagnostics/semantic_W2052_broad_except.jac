"""Fixture for W2052: except clause catches overly broad exception type."""

with entry {
    try {
        x = 1 / 0;
    } except Exception as e {  # <-- Warning W2052: overly broad
        print(e);
    }

    try {
        x = 1 / 0;
    } except ZeroDivisionError as e {  # <-- Ok: specific
        print(e);
    }
}
