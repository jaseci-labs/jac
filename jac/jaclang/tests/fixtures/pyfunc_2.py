from __future__ import annotations

# flake8: noqa

"""Python function for testing py imports."""


def count_up_to(n: int):
    """Count up to n"""
    count = 1
    while count <= n:
        yield count
        count += 1


counter = count_up_to(5)
for num in counter:
    print(num)

x = 0b1010
x &= 0b1100
print(bin(x))


path = r"C:\Users\Alice\Documents"
print(path)  # output : C:\Users\Alice\Documents
print(type(path))  # output : <class 'str'>

hello_world_bytes = b"\x48\x65\x6c\x6c\x6f\x20\x57\x6f\x72\x6c\x64"
print(hello_world_bytes)  # output : b'Hello World'
print(type(hello_world_bytes))  # output : <class 'bytes'>

ret_str = r"Hello\\nWorld"
print(ret_str)  # output : Hello\\nWorld

br = rb"Hello\\nWorld"
print(br)  # output : b'Hello\\\\nWorld'
print(type(br))  # output : <class 'bytes'>

rb = rb"Hello\\nWorld"
print(rb)  # output : b'Hello\\\\nWorld'
print(type(rb))  # output : <class 'bytes'>


squares = {num: num**2 for num in range(1, 6)}
even_squares_set = {num**2 for num in range(1, 11) if num % 2 == 0}
squares_generator = (num**2 for num in range(1, 6))
squares_list = [num**2 for num in squares_generator]

print("\n".join([str(squares), str(even_squares_set), str(squares_list)]))
print(
    {"a": "b", "c": "d"},  # Dictionary value
    {"a"},  # Set value
    ("a",),  # Tuple value
    ["a"],  # List value
)
from abc import ABC, abstractmethod


class Calculator(ABC):
    @staticmethod
    def multiply(a: float, b: float) -> float:
        return a * b

    @abstractmethod
    def substract(self, x: float, y: float) -> float:
        pass

    def add(self, number: float, *a: tuple) -> str:
        return str(number * sum(a))


class Substractor(Calculator):
    def substract(self, x: float, y: float) -> float:
        return x - y


class Divider:
    def divide(self, x: float, y: float):
        return x / y


sub = Substractor()
div = Divider()
print(div.divide(55, 11))
print(Calculator.multiply(9, -2))
print(sub.add(5, 20, 34, 56))
print(sub.substract(9, -2))


def foo(value: int):
    assert value > 0, "Value must be positive"


try:
    foo(-5)
except AssertionError as e:
    print("Asserted:", e)

a = b = 16
c = 18
print(a, b, c)
a >>= 2
print(a)
a <<= 2
print(a)
c //= 4
print(c)


class X:
    a_b = 67
    y = "aaa" + f"b{a_b}bbcc"


c = (3, 4, 5)
l_1 = [2, 3, 4, 5]


def entry():
    x = X

    a = "abcde...."
    b = True
    c = bin(12)
    d = hex(78)
    # e = 0x4E
    print(l_1, a, b, c, d)
    print(x.y)


# Run the entry block
entry()
print("Hello world!")
a = [2, 4, 5, 7, 8]
b = [4, 8, 9, 13, 20]
c = len(a) + len(b)
print(c)

"""A Docstring can be added the head of any module.

Any element in the module can also have a docstring.
If there is only one docstring before the first element,
it is assumed to be a module docstring.
"""

"""A docstring for add function"""


def add(a: int, b: int) -> int:
    return a + b


def subtract(a: int, b: int) -> int:
    return a - b


if __name__ == "__main__":
    print(add(1, subtract(3, 1)))

p = print
p("&:", 5 & 3)
p("|:", 5 | 3)
p("^:", 5 ^ 3)
p("~:", ~5)
p("<<:", 5 << 1)
p(">>:", 5 >> 1)

a = 9.2
b = 44
c = [2, 4, 6, 10]
d = {"name": "john", "age": 28}
e = ("jaseci", 5, 4, 14)
f = True
g = "Jaseci"
h = {5, 8, 12, "unique"}
print(type(a), "\n", type(b), "\n", type(c), "\n", type(d), "\n", type(e))
print(type(f), "\n", type(g), "\n", type(h))

print("Welcome to the world of Jaseci!")


def add(x: int, y: int) -> int:
    return x + y


print(add(10, 89))

for i in range(9):
    if i > 2:
        print("loop is stopped!!")
        break
    print(i)
for i in "WIN":
    if i == "W":
        continue
    print(i)

from enum import Enum, auto


class Color(Enum):
    RED = 1
    pencil = auto()
    print("text")


print(Color.RED.value)
if 5 / 2 == 1:
    x = 1
else:
    x = 2

print(x)
x = "a"
y = 25
print(f"Hello {x} {y} {{This is an escaped curly brace}}")
person = {"name": "Jane", "age": 25}
print(f"Hello, {person['name']}! You're {person['age']} years old.")
print("This is the first line.\n This is the second line.")
print("This will not print.\r This will be printed")
print("This is \t tabbed.")
print("Line 1\x0cLine 2")
words = ["Hello", "World!", "I", "am", "a", "Jactastic!"]
print(
    f'''{"""
""".join(words)}'''
)
for i in "ban":
    for j in range(1, 3):
        for k in range(1, 3, 1):
            print(i, j, k)

import math


class Circle:
    def __init__(self, radius: float):
        self.radius = radius

    def area(self):
        return math.pi * self.radius * self.radius


def foo(n_1: float):
    return n_1**2


print("Hello World!")
print(foo(7))
print(int(Circle(10).area()))


def foo(x: int, y: int, z: int) -> None:
    return (x * y, y * z)


a = 5
output = foo(x=4, y=4 if a % 3 == 2 else 3, z=9)
print(output)

x = "Jaclang "


def foo() -> None:
    global x
    x = "Jaclang is "
    y = "Awesome"

    def foo2() -> tuple[str, str]:
        nonlocal y
        y = "Fantastic"
        return (x, y)

    print(x, y)
    print(foo2())


foo()

node = 90
print(node)
