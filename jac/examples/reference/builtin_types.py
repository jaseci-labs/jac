from __future__ import annotations
from typing import Any

s: str = "hello"
print(s)
i: int = 42
print(i)
f: float = 3.14
print(f)
lst: list = [1, 2, 3]
print(lst)
tup: tuple = (1, 2, 3)
print(tup)
st: set = {1, 2, 3}
print(st)
dct: dict = {"key": "value"}
print(dct)
b: bool = True
print(b)
byt: bytes = b"binary"
print(byt)
a: Any = "anything"
print(a)
a = 123
print(a)
t: type = str
print(t)


def typed_func(x: int, y: str) -> tuple:
    return (x, y)


result = typed_func(10, "test")
print(result)
