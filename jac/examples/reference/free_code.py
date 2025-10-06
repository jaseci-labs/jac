"""Free code: Entry blocks for top-level executable code."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
import math

class Circle(_jl.Obj):
    radius: float

    def area(self) -> float:
        return math.pi * self.radius ** 2

def square(n: float) -> float:
    return n ** 2
print('Free code execution')
print(square(7))
print(int(Circle(radius=10).area()))
if __name__ == 'custom':
    print('Named entry point')
