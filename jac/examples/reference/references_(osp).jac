"""References (OSP): Reference operator (&) for pass-by-reference semantics."""

with entry {
    # The & operator creates a reference to a variable
    # This is currently unused/deprecated in Jac but defined in grammar
    x = 42;

    # Note: BW_AND as reference operator is in grammar but may not be active
    # The ref rule: BW_AND? pipe_call allows optional & prefix
    # Example (if supported): ref_x = &x;
    print("Reference operator & is defined in grammar (ref rule) but currently unused");
}
