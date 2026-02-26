with entry {
    d: dict[str, int] = {};
    d.pop("key");  # <-- Ok
    d.pop("key", 1);  # <-- Ok

    # Error cases
    d.pop(); # <-- Error: Missing argument
    d.pop(1); # <-- Error: Key type mismatch
    d.pop("key", 1, 2); # <-- Error: Too many arguments
}
