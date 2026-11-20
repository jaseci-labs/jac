"""Test list(Generator[T, _, _]) returns list[T]."""

import from typing { Generator }

obj Item {
    has id: int;
}

glob items_gen: Generator[Item, None, None];

def get_items_from_generator(gen: Generator[Item, None, None]) -> list[Item] {
    items = list(gen);
    return items;
}

def test_dict_keys -> list[str] {
    d: dict[str, int] = {"a": 1, "b": 2};
    keys = list(d.keys());
    return keys;
}

def test_range -> list[int] {
    nums = list(range(10));
    return nums;
}
