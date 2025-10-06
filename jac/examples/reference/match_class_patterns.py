from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Point(_jl.Obj):
    x: float
    y: float

class Circle(_jl.Obj):
    center: Point
    radius: float
data = Point(x=9, y=0)
match data:
    case Point(int(a), y=0):
        print(f'Point on x-axis with x={a}')
    case _:
        print('Point not on axis')
p1 = Point(x=5.0, y=10.0)
match p1:
    case Point(x=x_val, y=y_val):
        print(f'Point at ({x_val}, {y_val})')
p2 = Point(x=0.0, y=0.0)
match p2:
    case Point(x=0.0, y=0.0):
        print('Point at origin')
    case Point(x=0.0, y=y):
        print(f'Point on y-axis at y={y}')
    case _:
        print('Point elsewhere')
c = Circle(center=Point(x=3.0, y=4.0), radius=5.0)
match c:
    case Circle(center=Point(x=cx, y=cy), radius=r):
        print(f'Circle at ({cx}, {cy}) with radius {r}')
