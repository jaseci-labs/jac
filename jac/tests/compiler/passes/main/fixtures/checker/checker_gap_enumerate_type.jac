"""Gap: enumerate() does not infer element types correctly.

When using `for (idx, item) in enumerate(items)` where items is a typed list,
the type checker should infer:
- idx: int
- item: the element type of the list

Currently, both idx and item are Unknown because:
1. enumerate(items) returns enumerate with empty type_args (should be enumerate[Item])
2. __iter__ returns Self which is not resolved
3. __next__ returns tuple[int, _T] but _T is not specialized

Expected: Type errors for invalid assignments to idx and item.
Actual: No type errors because types are Unknown.
"""

node Item {
    has id: int;
}

with entry {
    items: list[Item] = [Item(id=1), Item(id=2), Item(id=3)];

    for (idx, item) in enumerate(items) {
        # When fixed: idx is int, so assigning to str should error
        wrong_idx: str = idx;   # <-- Should Error: Cannot assign int to str

        # When fixed: item is Item, so assigning to int should error
        wrong_item: int = item;  # <-- Should Error: Cannot assign Item to int

        # When fixed: item.id should work since item is Item
        print(item.id);  # <-- Should work, currently errors with Unknown
    }
}
