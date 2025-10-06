"""F-string tokens: Formatted string literals with interpolation."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
x = 'World'
y = 42
print(f'Hello {x}! Number: {y}')
print(f'Value: {y}')
msg = f'\n    Multi-line\n    Value: {y}\n    '
print(msg)
print(f'Escaped: {{braces}} and value {y}')
print(f'Math: {5 + 3}, {10 * 2}')
text = 'hello'
print(f'Upper: {text.upper()}')
d = {'name': 'Alice', 'age': 30}
print(f'Name: {d['name']}, Age: {d['age']}')
age = 20
print(f'Status: {('Adult' if age >= 18 else 'Minor')}')
val = 100
print(f'Nested: {f'{val}'}')
print('Complete')
