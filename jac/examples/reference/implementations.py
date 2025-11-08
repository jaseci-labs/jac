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
