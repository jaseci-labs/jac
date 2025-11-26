"""Pipe back atomic expressions: Atomic backward pipe operator (<:) for right-to-left flow."""

from __future__ import annotations

print("Hello")
a = [2, 4, 5]
b = [6, 7, 8]
c = len(a) + len(b)
result = (lambda x: x * 3)(10)
print(c, result)
