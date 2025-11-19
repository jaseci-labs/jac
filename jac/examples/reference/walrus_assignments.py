from __future__ import annotations

if (x := 10) > 5:
    print(f"x = {x}")
i = 0
data = [1, 2, 3, 4, 5]
while ((item := data[i]) if i < len(data) else None) and i < 3:
    print(f"item: {item}")
    i += 1
result = (y := 20) + 10
print(f"y = {y}, result = {result}")
if (a := 5) and (b := 10):
    print(f"a = {a}, b = {b}")


def process(value: int) -> int:
    return value * 2


if (z := process(7)) > 10:
    print(f"z = {z}")
numbers = [1, 2, 3, 4, 5]
if (total := sum(numbers)) > 10:
    print(f"total = {total}")
if m := 5:
    if (n := (m * 2)) > 8:
        print(f"m = {m}, n = {n}")
