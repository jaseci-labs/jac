"""Unpack expressions: Unpacking with * (iterable) and ** (mapping)."""

from __future__ import annotations


def compute(a: int, b: int, c: int, d: int) -> int:
    return a + b + c + d


list1 = [1, 2, 3]
list2 = [4, 5, 6]
combined = [*list1, *list2]
dict1 = {"a": 1, "b": 2}
dict2 = {"c": 3, "d": 4}
merged = {**dict1, **dict2}
result1 = compute(**merged)
result2 = compute(**dict1, **dict2)
print(combined, merged, result1, result2)
