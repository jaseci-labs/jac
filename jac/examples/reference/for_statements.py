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
