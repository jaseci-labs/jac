"""Fixture for E0071: Empty except clause (bare except) must be last."""

with entry {
    # Bare except not last -- Error
    try {
        x = 1;
    } except {
        y = 2;  # <-- Error E0071: bare except must be last
    } except ValueError as e {
        z = 3;
    }

    # Bare except last -- Ok
    try {
        x = 1;
    } except ValueError as e {
        y = 2;
    } except {
        z = 3;  # <-- Ok
    }
}
