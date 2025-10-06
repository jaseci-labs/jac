"""Base module structure: Module and element docstrings, entry points.

This is the module-level docstring.
It describes the purpose of the entire module.
"""
from __future__ import annotations
from jaclang.runtimelib.builtin import *

def add(a: int, b: int) -> int:
    return a + b

def subtract(a: int, b: int) -> int:
    return a - b
print('Default entry:', add(5, subtract(8, 3)))
if __name__ == '__main__':
    print('Named entry:', add(1, subtract(3, 1)))
