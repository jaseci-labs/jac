from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Point(_jl.Obj):
    x: float
    y: float

def match_example(data: any) -> None:
    match data:
        case 42:
            print('Matched the value 42.')
        case True:
            print('Matched the singleton True.')
        case None:
            print('Matched the singleton None.')
        case [1, 2, 3]:
            print('Matched a specific sequence [1, 2, 3].')
        case [1, *rest, 3]:
            print(f'Matched a sequence starting with 1 and ending with 3. Middle: {rest}')
        case {'key1': 1, 'key2': 2, **rest}:
            print(f'Matched a mapping with key1 and key2. Rest: {rest}')
        case Point(int(a), y=0):
            print(f'Point with x={a} and y=0')
        case [1, 2, rest_val as value]:
            print(f'Matched a sequence and captured the last value: {value}')
        case [1, 2] | [3, 4]:
            print('Matched either the sequence [1, 2] or [3, 4].')
        case _:
            print('No match found.')
match_example(Point(x=9, y=0))
