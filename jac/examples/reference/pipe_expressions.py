"""Pipe expressions: Forward pipe operator (|>) for function chaining."""

from __future__ import annotations


def square(x: int) -> int:
    return x**2


def double(x: int) -> int:
    return x * 2


def add_ten(x: int) -> int:
    return x + 10


result1 = square(5)
result2 = square(double(add_ten(3)))
total = sum([1, 2, 3, 4, 5])
result3 = (lambda n: n * 3)(10)
print(result1, result2, total, result3)
