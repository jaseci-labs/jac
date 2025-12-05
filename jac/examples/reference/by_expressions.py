"""
By as an Operator Example

This example demonstrates the use of 'by' as an operator in various contexts,
including simple usage, chaining, arithmetic expressions, and assignments.
"""

from __future__ import annotations
from jaclang.lib import by_operator

result = by_operator('hello', 'world')
print('Simple by:', result)

result2 = by_operator('a', by_operator('b', 'c'))
print('Chained by:', result2)

result3 = by_operator(1 + 2, 3 * 4)
print('Arithmetic by:', result3)

x = by_operator('input', 'output')
print('Assignment with by:', x)
