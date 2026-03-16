"""Gap: Generic type parameter inference from function/constructor arguments.

When calling a generic function or constructor, the type parameter should be
inferred from the argument types.

For example:
- enumerate(items: list[Item]) should return enumerate[Item]
- zip(list[int], list[str]) should return zip[tuple[int, str]]

Currently, generic calls return the generic type without type_args populated,
so the type parameter remains unresolved.

This is the root cause of the enumerate issue - without proper inference,
enumerate(items) returns enumerate (no type_args) instead of enumerate[Item].
"""

node Item {
    has value: int;
}

# Test: Generic class constructor should infer type parameter
obj MyGeneric[T] {
    has data: T;

    def get_data -> T {
        return self.data;
    }
}

with entry {
    # Test 1: enumerate should infer T from iterable
    items: list[Item] = [Item(value=1), Item(value=2)];

    # enumerate(items) should be enumerate[Item]
    # __next__ should return tuple[int, Item]
    for (i, x) in enumerate(items) {
        # When fixed: x is Item, assigning to str should error
        wrong_x: str = x;  # <-- Should Error: Cannot assign Item to str
        print(x.value);    # <-- Should work, currently fails
    }

    # Test 2: Custom generic class should infer type parameter
    wrapper = MyGeneric(data=Item(value=42));
    # wrapper should be MyGeneric[Item]
    result = wrapper.get_data();
    # When fixed: result is Item, assigning to int should error
    wrong_result: int = result;  # <-- Should Error: Cannot assign Item to int
    print(result.value);         # <-- Should work if inference works
}
