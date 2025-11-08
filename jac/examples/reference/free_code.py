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
