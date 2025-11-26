from __future__ import annotations

x = 0
while x < 5:
    print(x)
    x += 1
a = 0
b = 10
while a < 5 and b > 5:
    print(f"a={a}, b={b}")
    a += 1
    b -= 1
count = 0
while count < 3:
    print(count)
    count += 1
else:
    print("completed")
i = 0
while i < 10:
    if i == 3:
        break
    print(i)
    i += 1
else:
    print("not reached")
num = 0
while num < 5:
    num += 1
    if num % 2 == 0:
        continue
    print(num)
counter = 0
while True:
    print(counter)
    counter += 1
    if counter >= 3:
        break
outer = 0
while outer < 2:
    inner = 0
    while inner < 2:
        print(f"{outer},{inner}")
        inner += 1
    outer += 1
