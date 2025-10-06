from __future__ import annotations
from jaclang.runtimelib.builtin import *

def simple_generator() -> None:
    yield 1
    yield 2
    yield 3

def yield_values() -> None:
    yield 'hello'
    yield 42
    yield [1, 2, 3]

def yield_none() -> None:
    yield

def yield_in_loop(n: int) -> None:
    for i in range(n):
        yield i

def yield_from_generator() -> None:
    yield from [1, 2, 3]
    yield from range(4, 7)

def conditional_yield(items: list) -> None:
    for item in items:
        if item % 2 == 0:
            yield item

def yield_with_expression() -> None:
    x = 10
    yield (x * 2)
    yield (x + 5)
print('simple_generator:')
for val in simple_generator():
    print(val)
print('yield_values:')
for val in yield_values():
    print(val)
print('yield_none:')
for val in yield_none():
    print(val)
print('yield_in_loop:')
for val in yield_in_loop(5):
    print(val)
print('yield_from_generator:')
for val in yield_from_generator():
    print(val)
print('conditional_yield:')
for val in conditional_yield([1, 2, 3, 4, 5, 6]):
    print(val)
print('yield_with_expression:')
for val in yield_with_expression():
    print(val)
