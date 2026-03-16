"""Fixture for E0058: break/continue used outside of a loop."""

with entry {
    break;     # <-- Error E0058
    continue;  # <-- Error E0058

    for i in [1, 2, 3] {
        break;     # <-- Ok
        continue;  # <-- Ok
    }
}
