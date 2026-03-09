"""Bug #31: With statement does not check context manager protocol.

The type checker has no exit_with_stmt method. Objects used in
`with` blocks are not validated as context managers (implementing
__enter__ and __exit__), and the `as` variable gets no type from
__enter__'s return type.

Expected: `with 42 as x:` should error because int is not a context manager.
"""

with entry {
    # Using a non-context-manager should be an error
    with 42 as x {  # <-- Should be Error (int is not a context manager)
        print(x);
    }

    # Using a valid context manager should infer the `as` variable type
    with open("test.txt") as f {
        # f should be typed as file object
        bad: int = f;  # <-- Should be Error (file not assignable to int)
    }
}
