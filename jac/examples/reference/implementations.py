"""Implementations: Forward declarations and impl blocks for deferred definitions."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
from enum import Enum, auto

@_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/implementations.jac')
def compute(x: int, y: int) -> int:
    return x + y

class Vehicle(_jl.Obj):
    name: str = 'Car'
    speed: int = 0

    def accelerate(self) -> None:
        self.speed += 10

@_jl.sem('', {'LOW': '', 'MEDIUM': '', 'HIGH': ''})
class Priority(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3
result = compute(5, 3)
v = Vehicle()
v.accelerate()
p = Priority.HIGH
print(result, v.name, v.speed, p.value)
