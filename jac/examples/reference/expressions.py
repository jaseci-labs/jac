"""Expressions: Ternary conditional (if-else) and lambda expressions."""

from __future__ import annotations

x = 1 if 5 / 2 == 1 else 2
status = "adult" if 20 >= 18 else "minor"
grade = "A" if 85 >= 90 else "B" if 85 >= 80 else "C"
square = lambda x: x**2
add = lambda a, b: a + b
multiply = lambda x, y: x * y
get_five = lambda: 5
abs_val = lambda n: n if n >= 0 else -n
print(x, status, grade, square(5), add(3, 4), multiply(6, 7), get_five(), abs_val(-10))
