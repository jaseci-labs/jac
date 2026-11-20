"""An unannotated local is frozen to its first binding's type, widened past
any literal: `s = ""` freezes `s` as `str`, so a different string is fine,
but a cross-type reassignment (str to int) still errors with the base type.
"""

with entry {
    # Frozen to `str` (widened from Literal[""]); a different string is Ok.
    s = "";
    s = "kjkkjk";  # <-- Ok

    # Same for non-empty initial literals.
    greeting = "hi";
    greeting = "bye";  # <-- Ok

    # Boolean literal widens to `bool`.
    flag = True;
    flag = False;  # <-- Ok

    # Cross-type reassignment is still rejected; the frozen type is `str`.
    name = "alice";
    name = 5;  # <-- Error
}
