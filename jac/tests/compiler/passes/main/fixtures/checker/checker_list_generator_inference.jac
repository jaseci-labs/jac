"""Test list() constructor type inference from Generator/Iterator types.

When calling list(generator), the type should be list[YieldType] where
YieldType is the first type argument of Generator[YieldType, SendType, ReturnType].

Currently, list(Generator[Item, None, None]) incorrectly returns list[NoneType]
instead of list[Item].
"""

import from typing { Generator }

obj Item {
    has id: int;
}

# Simulating a generator function without using yield syntax
glob items_gen: Generator[Item, None, None];

def get_items_from_generator(gen: Generator[Item, None, None]) -> list[Item] {
    # list(Generator[Item, None, None]) should be list[Item], not list[NoneType]
    items = list(gen);
    return items;  # <-- Error: Cannot return list[NoneType], expected list[Item]
}

def test_dict_keys -> list[str] {
    # dict.keys() returns KeysView which is Iterable[K]
    d: dict[str, int] = {"a": 1, "b": 2};
    keys = list(d.keys());
    return keys;  # Should work: list[str]
}

def test_range -> list[int] {
    # range() returns range which is Iterable[int]
    nums = list(range(10));
    return nums;
}
