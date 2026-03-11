"""Fixture for Bug #23: With statement alias typed as Unknown.

When using `with open(...) as f`, the alias `f` was typed as Unknown
because the type binding happened in exit_with_stmt (after body visited)
instead of enter_with_stmt (before body visited).
"""

with entry {
    with open("/tmp/test.txt", "w") as f {
        # f should be TextIOWrapper, not Unknown
        f.write("hello");

        # These should produce type errors
        bad: int = f;  # Error: TextIOWrapper not assignable to int
    }
}
