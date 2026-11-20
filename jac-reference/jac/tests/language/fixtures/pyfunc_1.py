# flake8: noqa

"""Python function for testing py imports."""

from enum import Enum


class ShapeType(Enum):
    """Enum for shape types"""

    CIRCLE = "Circle"
    UNKNOWN = "Unknown"
    print("hello")


f: int = 34
a = f > 3
qq = {}
e = "hello"
ff = b"hello"


def my_print(x: object) -> None:
    """Print function."""
    print(x)


print("Hello world!")


class MyClass2:
    """This is a docstring for MyClass."""

    def __init__(self) -> None:
        """Constructor docstring."""
        pass

    def my_method(self) -> None:
        """Method docstring."""
        print("My method")
        return "done"


name, age, city = "Alice", 30, "Wonderland"
message = f"Hello, my name is {name}, I am {age} years old, and I live in {city}."
result = f"The result of 5 times 7 is {5 * 7}."


def my_some_func(a: int, b: int) -> int:
    pass


class MyClass:
    """My class"""

    def __init__(self, x):
        self.x = x

    def my_method(self) -> None:
        print("My method")


class Student(MyClass):
    """Student class"""

    def __init__(self, x, y) -> None:
        super().__init__(x)
        self.y = y

    def my_method(self) -> None:
        print("My method")


a = 9
for i in range(a):
    print(i)
    b = i
    if i == 5:
        break
    print(b)
else:
    print(f"Loop completed normally{i}")


def fooo45() -> None:
    """Test func  fooo45"""
    pass


numbers = [1, 2, 3, 4, 5]
squares = [x**2 for x in numbers]
squares_dict = {x: x**2 for x in numbers}
squares_generator = (x**2 for x in numbers)
add = lambda x, y: x + y
numbers2 = [1, 2, 3, 3, 4, 5, 5]
unique_numbers2 = {x for x in numbers2}
even_numbers = {x for x in range(10) if x % 2 == 0}
coordinates = {(x, y) for x in range(3) for y in range(3)}
even_numbers4 = [num for num in range(11) if num % 2 == 0]
sentence = "the quick brown fox jumps over the lazy dog"
capitalized_words = [word.upper() for word in sentence.split() if len(word) > 3]
result78 = [
    (x, y) for x in range(1, 4) if x % 2 == 0 for y in range(1, 4) if y % 2 == 0
]
print(result78)


class Car:
    wheels: int = 4

    def __init__(self, make: str, model: str, year: int) -> None:
        self.make = make
        self.model = model
        self.year = year

    def display_car_info(self) -> None:
        print(f"Car Info: {self.year} {self.make} {self.model}")

    @staticmethod
    def get_wheels() -> int:
        return Car.wheels


car1 = Car("Toyota", "Camry", 2020)
car1.display_car_info()
print("Number of wheels:", Car.get_wheels())

p = print

p("Multiply:", 7 * 2)
p("Division:", 15 / 3)
p("Floor:", 15 // 3)
p("Modulo:", 17 % 5)
p("Expon:", 2**3)
p("combo:", (9 + 2) * 9 - 2)


for i in range(a):
    print(i)
    if i == 5:
        break
    print(b)
else:
    print(f"Loop completed normally{i}")

numbers = [1, 2, 3, 4, 5]
squares = [x**2 for x in numbers]
squares_dict = {x: x**2 for x in numbers}
squares_generator = (x**2 for x in numbers)
add = lambda x, y: x + y  # noqa


def my_decorator(func):
    """Decorator"""

    def wrapper():
        print("Something is happening before the function is called.")
        func()
        print("Something is happening after the function is called.")

    return wrapper


@my_decorator
def say_hello():
    """Say hello"""
    print("Hello!")


def print_base_classes(cls: type) -> type:
    print(f"Base classes of {cls.__name__}: {[c.__name__ for c in cls.__bases__]}")
    return cls


def foo(cls):
    return cls


class Animal:
    pass


class domestic:
    pass


@print_base_classes
class Mammal(Animal, domestic):
    pass


s = []
a = [1, 2, 3, 4, 5]
b = (1, 2, 3, 4, 5)
x = ()
c = {1, 2, 3, 4, 5}
d = {1: "one", 2: "two", 3: "three", 4: "four", 5: "five"}


x = {}
x = {"name": "John", "age": 30, "city": "New York"}

x = 5
while x < 10:
    x += 1
    print("hello")

try:
    result = 10 / 0
except ZeroDivisionError:
    print("Cannot divide by zero!")
else:
    print(result)
finally:
    print("This will always execute.")


def foox():
    return 9 + 4


a, b, c = 1, 2, 3
x = y = z = 0
# first, *rest = [1, 2, 3, 4, 5]


def greet(name, greeting="Hello") -> None:
    """Greet someone."""
    print(f"{greeting}, {name}")


greet("Alice")
greet("Bob", greeting="Hi")


def average(*args) -> float:
    """Average function"""
    return sum(args) / len(args)


avg = average(1, 2, 3, 4, 5)


def greet2(**kwargs) -> None:
    """Greet someone."""
    print(f"Hello, {kwargs['name']}!")


greet2(name="Alice", age=30)

name = "Alice"
age = 30
print(f"Name: {name}, Age: {age}")


x = True
y = False
z = x and y


x = 5
assert x == 5, "x should be equal to 5"

uu = 9
if uu == 9:
    print("uu is 9")
elif uu == 10:
    print("uu is 10")
else:
    print("uu is not 9 or 10")


def my_functionx() -> None:
    """My function"""

    def my_inner_function():
        """Inner function"""
        return 9

    my_inner_function()
    for i in range(10):
        if i == 5:
            break
        if i == 3:
            continue
    pass


x = 90
if not isinstance(x, int):
    raise ValueError("x must be an integer")
else:
    print(x)


my_list = [1, 2, 3, 4, 5]
del my_list[2]
print(my_list)


x = 5
y = 10
z = 15

if not x == y:
    print("x is not equal to y")

if x == y or y == z:
    print("Either x is equal to y or y is equal to z")
else:
    print("Neither x is equal to y nor y is equal to z")
