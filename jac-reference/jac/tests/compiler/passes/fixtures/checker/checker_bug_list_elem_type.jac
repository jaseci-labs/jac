"""Bug #3: List element type inference only considers the first element.

For [1, "hello"], the type checker infers list[int] instead of
list[int | str]. This means assigning elements from the list to str
would fail even though the list contains strings.

Expected: heterogeneous lists should infer the union of element types.
"""

with entry {
    # Homogeneous list - first element determines type (works today)
    ints: list[int] = [1, 2, 3];  # <-- Ok

    # Heterogeneous list - BUG: type is list[int] not list[int | str]
    mixed = [1, "hello", 2, "world"];

    # If the type system correctly inferred list[int | str], then:
    # - Assigning to list[int] should Error (str not assignable to int)
    # - Assigning to list should be Ok
    wrong: list[int] = mixed;  # <-- Should be Error (list[int|str] != list[int])
}
