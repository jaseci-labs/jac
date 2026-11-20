# flake8: noqa

"""Python function for testing py imports."""

global a, X, y, z
a = 5
X = 10
y = 15
z = 20

print(a, X, y, z)

x = 15
if 0 <= x <= 5:
    print("Not Bad")
elif 6 <= x <= 10:
    print("Average")
else:
    print("Good Enough")

from enum import Enum


def foo() -> None:
    return "Hello"


class vehicle:
    def __init__(self) -> None:
        self.name = "Car"


class Size(Enum):
    Small = 1
    Medium = 2
    Large = 3


car = vehicle()
print(foo())
print(car.name)
print(Size.Medium.value)

import os
from math import sqrt as square_root
import datetime as dt

for i in range(int(square_root(dt.datetime.now().year))):
    print(os.getcwd())

print("hello ")


def foo():
    print("world")


foo()

x = lambda a, b: a + b
print(x(5, 4))

if 5 > 4:
    print("True")
elif "a" != "a":
    print("'a' is 'a' ")
else:
    print("False")
a = [1, 2, 3]
b = [1, 2, 3]
print(a is b)
print(3 in a)

print(True or False)
print(False and False)

day = "sunday"
match day:
    case "monday":
        print("confirmed")
    case _ as day:
        print("other")

num = 89
match num:
    case 89:
        print("Correct")
    case 8:
        print("Nope")

data = {"key1": 1, "key2": 2, "232": 3453}

match data:
    case {"key1": 1, "key2": 2, **rest}:
        print(f"Matched a mapping with key1 and key2. Rest: {rest}")


class Point:
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y


def match_example(data: any):
    match data:
        # MatchValue
        case 42:
            print("Matched the value 42.")

        # MatchSingleton
        case True:
            print("Matched the singleton True.")
        case None:
            print("Matched the singleton None.")

        # MatchSequence
        case [1, 2, 3]:
            print("Matched a specific sequence [1, 2, 3].")

        # MatchStar
        case [1, *rest, 3]:
            print(
                f"Matched a sequence starting with 1 and ending with 3. Middle: {rest}"
            )

        # MatchMapping
        case {"key1": 1, "key2": 2, **rest}:
            print(f"Matched a mapping with key1 and key2. Rest: {rest}")

        # MatchClass
        case Point(x=int(a), y=0):
            print(f"Point with x={a} and y=0")

        # MatchAs
        case [1, 2, rest_val as value]:
            print(f"Matched a sequence and captured the last value: {value}")

        # MatchOr
        case [1, 2] | [3, 4]:
            print("Matched either the sequence [1, 2] or [3, 4].")

        # case _:
        #     print("No match found.")


match_example(Point(x=9, y=0))

data = [1, 2, 3]
match data:
    case [1, 2, 3]:
        print("Matched")
    case _:
        print("Not Found")
data = True
match True:
    # MatchSingleton
    case True:
        print("Matched the singleton True.")
    case None:
        print("Matched the singleton None.")
a = 8
match a:
    case 7:
        print("Doable")
    case _:
        print("Undoable")


class Animal:
    def __init__(self, animal_type):
        self.animal_type = animal_type


class Dog(Animal):
    def __init__(self, breed):
        super().__init__("Dog")
        self.breed = breed
        self.sound = ""
        self._post_init()

    def _post_init(self):
        self.sound = "woof woof"


dog1 = Dog(breed="Labrador")
print(dog1.animal_type, dog1.breed, dog1.sound)


def double(x: int) -> int:
    return x * 2


number = 5
result = double(number)
print(result)


def square(x: int) -> int:
    return x**2


number = 5
result = square(number)
print(result)


def foo(value: int):
    if value < 0:
        raise ValueError("Value must be non-negative")


try:
    foo(-1)
except ValueError as e:
    print("Raised:", e)


try:
    with open("test.txt") as file:
        print(file.read())
except:
    print("File not found")

try:
    with open("test.txt") as file:
        print(file.read())
except FileNotFoundError:
    print("File not found")

if 5 < 0:
    raise ValueError("A value error occurred")
elif 3 < 1:
    try:
        x = 1 / 0
    except ZeroDivisionError as e:
        raise ValueError("Error occurred") from e
else:
    print("No error occurred")


def foo():
    a = 42
    if a > 0:
        return
    return a


print("Returned:", foo())


class Sample:
    def __init__(self):
        self.my_list = [1, 2, 3]
        self.my_dict = {"name": "John", "age": 30}


def main():
    sample_instance = Sample()
    first, second = sample_instance.my_list[2], sample_instance.my_dict["name"]

    print(first, second)


main()


import unittest


class TestCases(unittest.TestCase):
    def test_test1(self):
        self.assertAlmostEqual(4.99999, 4.99999)

    def test_test2(self):
        self.assertEqual(5, 5)

    def test_test3(self):
        self.assertIn("e", "qwerty")


if __name__ == "__main__":
    unittest.main()


def foo(first: int, second: int) -> None:
    print(first, second)


val1 = (3,) + (4,)
val2 = (val1[0] * val1[1], val1[0] + val1[1])
foo(second=val2[1], first=val2[0])
foo(first=val2[0], second=val2[1])


def combine_via_func(a: int, b: int, c: int, d: int) -> int:
    return a + b + c + d


def myFunc():
    yield "Hello"
    yield 91
    yield "Good Bye"


x = myFunc()

for z in x:
    print(z)
