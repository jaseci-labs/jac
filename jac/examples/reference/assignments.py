from __future__ import annotations

x = 10
print(x)
a = b = c = 20
print(f"{a} {b} {c}")
value = 100
print(value)
age: int = 25
name: str = "Alice"
print(f"{age} {name}")
result: str
result = "computed"
print(result)
count: int = 5
print(count)
num: float
num = 10
num += 5
num -= 3
num *= 2
num /= 4
num %= 5
num **= 2
num //= 3
print(num)
bits = 12
bits &= 7
bits |= 3
bits ^= 5
bits <<= 2
bits >>= 1
print(bits)
x, y = (10, 20)
print(f"{x} {y}")
x, y = (y, x)
print(f"{x} {y}")
[p, q, r] = [1, 2, 3]
print(f"{p} {q} {r}")
m, (n, o) = (5, (6, 7))
print(f"{m} {n} {o}")
first, *rest = [1, 2, 3, 4, 5]
print(f"{first} {rest}")
head, *middle, tail = [10, 20, 30, 40, 50]
print(f"{head} {middle} {tail}")
*beginning, last = [100, 200, 300]
print(f"{beginning} {last}")
