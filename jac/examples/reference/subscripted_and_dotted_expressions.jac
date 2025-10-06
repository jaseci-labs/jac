"""Subscripted and dotted expressions: Index access, slicing, and member access."""

obj Sample {
    has items: list = [10, 20, 30, 40, 50],
        data: dict = {"name": "Alice", "age": 30},
        value: int = 42;
}

with entry {
    s = Sample();

    # Dot notation for member access
    val = s.value;

    # Subscripted access for lists and dicts
    item1 = s.items[0];
    item2 = s.items[-1];
    name = s.data["name"];

    # Slicing
    slice1 = s.items[1:4];
    slice2 = s.items[:3];
    slice3 = s.items[2:];

    # Chained access
    first_char = s.data["name"][0];

    # Null-safe access with ?
    safe_val = s?.value;

    print(val, item1, item2, name, slice1, slice2, slice3, first_char, safe_val);
}
