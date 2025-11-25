from __future__ import annotations
from jaclang.lib import destroy

x = [1, 2, 3, 4, 5]
print(x)
destroy([x[2]])
del x[2]
print(x)
y = 100
print(y)
destroy([y])
del y
d = {"a": 1, "b": 2, "c": 3}
print(d)
destroy([d["b"]])
del d["b"]
print(d)
numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
print(numbers)
destroy([numbers[2:5]])
del numbers[2:5]
print(numbers)
matrix = [[1, 2], [3, 4], [5, 6]]
print(matrix)
destroy([matrix[1]])
del matrix[1]
print(matrix)
lst = [10, 20, 30]
destroy([lst[1]])
del lst[1]
print(lst)
data = [0, 1, 2, 3, 4, 5]
destroy([data[0]])
del data[0]
destroy([data[2]])
del data[2]
print(data)
