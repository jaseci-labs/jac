"""Pipe back expressions: Backward pipe operator (<|) for right-to-left function application."""

from __future__ import annotations


def double(x: int) -> int:
    return x * 2


def triple(x: int) -> int:
    return x * 3


def add_five(x: int) -> int:
    return x + 5


result1 = double(5)
result2 = add_five(10)
result3 = (lambda n: n * 3)(10)
total = sum([1, 2, 3, 4, 5])
temp = double(2)
result4 = triple(temp)
print(result1, result2, result3, total, result4)
