"""Fixture for E2055: return in finally block may swallow exception."""

def bad_finally() -> int {
    try {
        raise ValueError("oops");
    } finally {
        return 42;  # <-- Error E2055: return in finally swallows exception
    }
}

def ok_finally() -> int {
    try {
        return 1;
    } finally {
        print("cleanup");  # <-- Ok: no return/break/continue
    }
}
