"""Simple Python script used by CLI integration tests."""

a = 5
b = 3

print("Hello, World!")
sum_ab = a + b
print("Sum:", sum_ab)

num = 7
if num % 2 == 0:
    print(num, "is even")
else:
    print(num, "is odd")

fruits = ["apple", "banana", "cherry"]
for fruit in fruits:
    print(fruit)


def greet(name: str) -> str:
    return f"Hello, {name}!"


print(greet("Alice"))
