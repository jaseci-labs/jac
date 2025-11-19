"""Atomic expressions: Atomic expressions and literals (strings, numbers, bools, None, types)."""

from __future__ import annotations
from enum import Enum, auto


class NumEnum(Enum):
    aa = 67
    y = 68


s = "string"
b1 = True
b2 = False
n = None
dec = 42
binary = 12
octal = 493
hexa = 255
flt = 3.14
sci = 15000000000.0
ellip = ...
result = (5 + 3) * 2
var = 100
type1 = str
type2 = int
tpl = (1, 2, 3)
lst = [1, 2, 3]
dct = {"k": "v"}
st = {1, 2, 3}
multi = "Hello World"
name = "Alice"
fstr = f"Hello {name}"
print(dec, binary, octal, hexa, flt, sci, multi, fstr, NumEnum.aa.value)
