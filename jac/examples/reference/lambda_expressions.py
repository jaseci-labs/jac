from __future__ import annotations

add = lambda a, b: a + b
print(add(5, 3))
get_value = lambda: 42
print(get_value())
multiply = lambda x, y: x * y
print(multiply(4, 5))
get_default = lambda: 100
print(get_default())
power = lambda x=2, y=3: x**y
print(power())
print(power(5))
print(power(5, 2))
numbers = [1, 2, 3, 4, 5]
squared = list(map(lambda x: x**2, numbers))
print(squared)
evens = list(filter(lambda x: x % 2 == 0, numbers))
print(evens)
max_val = lambda a, b: a if a > b else b
print(max_val(10, 20))
print(max_val(30, 15))
make_adder = lambda x: lambda y: x + y
add_five = make_adder(5)
print(add_five(10))
words = ["apple", "pie", "a", "cherry"]
sorted_words = sorted(words, key=lambda s: len(s))
print(sorted_words)
