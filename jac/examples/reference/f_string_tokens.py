x = "a"
y = 25
print(f"Hello {x} {y} {{This is an escaped curly brace}}")
person = {"name": "Jane", "age": 25}
print(f"Hello, {person['name']}! You're {person['age']} years old.")
print("This is the first line.\n This is the second line.")
print("This will not print.\r This will be printed")
print("This is \t tabbed.")
print("Line 1\x0cLine 2")
words = ["Hello", "World!", "I", "am", "a", "Jactastic!"]
print(
    f'''{"""
""".join(words)}'''
)
