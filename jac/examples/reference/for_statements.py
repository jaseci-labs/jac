from __future__ import annotations

for x in [1, 2, 3]:
    print(x)
for i in range(5):
    print(i)
i = 0
while i < 5:
    print(i)
    i += 1
i = 10
while i > 0:
    print(i)
    i -= 1
i = 0
while i < 10:
    print(i)
    i += 2
for x in [1, 2, 3]:
    print(x)
else:
    print("completed")
for x in range(10):
    if x == 3:
        break
    print(x)
else:
    print("not reached")
for x in range(5):
    if x % 2 == 0:
        continue
    print(x)
for i in range(3):
    for j in range(2):
        print(f"{i},{j}")
for char in "abc":
    print(char)
d = {"a": 1, "b": 2}
for key in d:
    print(key)
for s in ["a", "b"]:
    j = 0
    while j < 2:
        print(f"{s}{j}")
        j += 1
pairs = [(1, 2), (3, 4), (5, 6)]
for a, b in pairs:
    print(f"a={a}, b={b}")
matrix = [[1, 2, 3], [4, 5, 6]]
for x, y, z in matrix:
    print(f"x={x}, y={y}, z={z}")
nested = [("alice", (10, 20)), ("bob", (30, 40))]
for name, (x, y) in nested:
    print(f"{name}: x={x}, y={y}")
items = [(1, 2, 3, 4), (5, 6, 7, 8)]
for first, *rest in items:
    print(f"first={first}, rest={rest}")
sequences = [(1, 2, 3, 4, 5), (6, 7, 8, 9, 10)]
for first, *middle, last in sequences:
    print(f"first={first}, middle={middle}, last={last}")
data = {"name": "Alice", "age": 30, "city": "NYC"}
for key, value in data.items():
    print(f"{key}: {value}")
coords = [(10, 20), (30, 40), (50, 60)]
for i, (x, y) in enumerate(coords):
    print(f"Point {i}: ({x}, {y})")
xs = [1, 2, 3]
ys = [10, 20, 30]
for x, y in zip(xs, ys):
    print(f"x={x}, y={y}")
as_ = [1, 2, 3]
bs = [4, 5, 6]
cs = [7, 8, 9]
for i, (a, b, c) in enumerate(zip(as_, bs, cs)):
    print(f"Index {i}: a={a}, b={b}, c={c}")
