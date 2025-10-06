from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
x = [1, 2, 3, 4, 5]
print(x)
_jl.destroy([x[2]])
del x[2]
print(x)
y = 100
print(y)
_jl.destroy([y])
del y
d = {'a': 1, 'b': 2, 'c': 3}
print(d)
_jl.destroy([d['b']])
del d['b']
print(d)
numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
print(numbers)
_jl.destroy([numbers[2:5]])
del numbers[2:5]
print(numbers)
matrix = [[1, 2], [3, 4], [5, 6]]
print(matrix)
_jl.destroy([matrix[1]])
del matrix[1]
print(matrix)
lst = [10, 20, 30]
_jl.destroy([lst[1]])
del lst[1]
print(lst)
data = [0, 1, 2, 3, 4, 5]
_jl.destroy([data[0]])
del data[0]
_jl.destroy([data[2]])
del data[2]
print(data)
