"""With entry blocks: Entry blocks for top-level executable code."""

from __future__ import annotations
from jaclang.lib import Obj
import math


class Circle(Obj):
    radius: float

    def area(self) -> float:
        return math.pi * self.radius**2


def square(n: float) -> float:
    return n**2


print("Entry block execution")
print(square(7))
print(int(Circle(radius=10).area()))
if __name__ == "__main__":
    print("Main entry point (only when run directly)")
