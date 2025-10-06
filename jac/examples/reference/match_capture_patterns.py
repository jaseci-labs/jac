from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
day = 'sunday'
match day:
    case 'monday':
        print("It's Monday")
    case _:
        print('Wildcard matched: not Monday')
value = 42
match value:
    case val as captured:
        print(f'Captured value: {captured}')
data = [1, 2, 3]
match data:
    case [first, second as mid, third]:
        print(f'First: {first}, captured middle: {mid}, third: {third}')

class Point(_jl.Obj):
    x: float
    y: float
p = Point(x=5.0, y=10.0)
match p:
    case Point(x=x_val, y=y_val) as point:
        print(f'Captured point: {point}, x={x_val}, y={y_val}')
