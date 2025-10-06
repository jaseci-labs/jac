"""Atomic expressions: Atomic forward pipe operator (:>) for chaining."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
print('Hello')
print(type('Test'))
result = (lambda x: x + 10)((lambda x: x * 2)(5))
print(result)
