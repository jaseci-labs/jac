"""Match statements: Pattern matching with all pattern types."""

from __future__ import annotations
from jaclang.lib import Obj
from typing import TypedDict


class Point(Obj):
    x: float
    y: float


class Circle(Obj):
    center: Point
    radius: float


class Rectangle(Obj):
    width: float
    height: float


status_code = 200
match status_code:
    case 200:
        print("OK")
    case 404:
        print("Not Found")
    case 500:
        print("Server Error")
    case _:
        print("Other status")
pi = 3.14
match pi:
    case 3.14:
        print("Matched pi")
    case 2.71:
        print("Matched e")
    case _:
        print("Other number")
command = "start"
match command:
    case "start":
        print("Starting")
    case "stop":
        print("Stopping")
    case "pause":
        print("Pausing")
    case _:
        print("Unknown command")
flag = True
match flag:
    case True:
        print("Flag is True")
    case False:
        print("Flag is False")
optional_value = None
match optional_value:
    case None:
        print("Value is None")
    case _:
        print("Value exists")
value = 42
match value:
    case x:
        print(f"Captured value: {x}")
day = "sunday"
match day:
    case "monday":
        print("It's Monday")
    case _:
        print("Not Monday")
number = 100
match number:
    case x as captured_num:
        print(f"Captured as: {captured_num}")
coords = [1, 2, 3]
match coords:
    case [1, 2, 3]:
        print("Matched exact sequence")
    case _:
        print("Different sequence")
point = [10, 20]
match point:
    case [x, y]:
        print(f"Point at ({x}, {y})")
numbers = [1, 2, 3, 4, 5]
match numbers:
    case [first, *middle, last]:
        print(f"First: {first}, middle: {middle}, last: {last}")
    case [*all_items]:
        print(f"All items: {all_items}")
data = [100, 200, 300, 400]
match data:
    case [*start, 400]:
        print(f"Ends with 400, start: {start}")
    case [100, *rest_ints]:
        print(f"Starts with 100, rest: {rest_ints}")
matrix = [[1, 2], [3, 4]]
match matrix:
    case [[a, b], [c, d]]:
        print(f"2x2 matrix: [{a},{b}], [{c},{d}]")
user = {"name": "Alice", "age": 30}
match user:
    case {"name": "Alice", "age": 30}:
        print("Matched exact user")
    case _:
        print("Different user")
person = {"id": 123, "role": "admin"}
match person:
    case {"id": user_id, "role": user_role}:
        print(f"User {user_id} is {user_role}")
config = {"host": "localhost", "port": 8080, "debug": True, "timeout": 30}
match config:
    case {"host": h, "port": p, **rest}:
        print(f"Server: {h}:{p}, other settings: {rest}")
response = {"status": 200, "data": {"name": "Bob", "score": 95}}
match response:
    case {"status": 200, "data": {"name": n, "score": s}}:
        print(f"Success: {n} scored {s}")
p1 = Point(x=5.0, y=10.0)
match p1:
    case Point(x=x_val, y=y_val):
        print(f"Point at ({x_val}, {y_val})")
origin = Point(x=0.0, y=0.0)
match origin:
    case Point(x=0.0, y=0.0):
        print("Point at origin")
    case Point(x=0.0, y=yf):
        print(f"On y-axis at {yf}")
    case Point(x=xf, y=0.0):
        print(f"On x-axis at {xf}")
    case _:
        print("Point elsewhere")
circle = Circle(center=Point(x=3.0, y=4.0), radius=5.0)
match circle:
    case Circle(center=Point(x=cx, y=cy), radius=r):
        print(f"Circle at ({cx}, {cy}) with radius {r}")
rect = Rectangle(width=10.0, height=20.0)
match rect:
    case Rectangle(width=w, height=h) as captured_rect:
        print(f"Rectangle {w}x{h}, object: {captured_rect}")
code = 404
match code:
    case 200 | 201 | 204:
        print("Success status")
    case 400 | 401 | 403 | 404:
        print("Client error")
    case 500 | 502 | 503:
        print("Server error")
    case _:
        print("Other code")
age = 25
match age:
    case x if x < 18:
        print("Minor")
    case x if x < 65:
        print("Adult")
    case x:
        print("Senior")
score = 85
match score:
    case s if s >= 90:
        print("Grade: A")
    case s if s >= 80:
        print("Grade: B")
    case s if s >= 70:
        print("Grade: C")
    case s if s >= 60:
        print("Grade: D")
    case _:
        print("Grade: F")


class _Shape(TypedDict):
    type: str
    center: list[int]
    radius: int


shape_data: _Shape = {"type": "circle", "center": [0, 0], "radius": 10}
match shape_data:
    case {"type": "circle", "center": [x, y], "radius": r}:
        print(f"Circle at ({x},{y}) r={r}")
    case {"type": "rectangle", "corners": [[x1, y1], [x2, y2]]}:
        print(f"Rectangle from ({x1},{y1}) to ({x2},{y2})")
    case _:
        print("Unknown shape")
result = "success"
match result:
    case "success":
        print("Operation succeeded")
        status_val = 200
        print(f"Status code: {status_val}")
    case "error":
        print("Operation failed")
        status_val = 500
        print(f"Status code: {status_val}")
    case _:
        print("Unknown result")
        status_val = 0
print("Match patterns demonstration complete")
