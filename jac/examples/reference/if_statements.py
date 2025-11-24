from __future__ import annotations

x = 10
if x > 5:
    print("x is greater than 5")
age = 18
if age >= 18:
    print("adult")
else:
    print("minor")
score = 85
if score >= 90:
    print("A")
elif score >= 80:
    print("B")
elif score >= 70:
    print("C")
else:
    print("F")
value = 15
if value < 5:
    print("very low")
elif value < 10:
    print("low")
elif value < 15:
    print("medium")
elif value < 20:
    print("high")
else:
    print("very high")
a = 15
b = 20
if a > 10:
    print("a > 10")
    if b > 15:
        print("b > 15")
        if a + b > 30:
            print("a + b > 30")
if a > 5 and b > 10:
    print("both conditions true")
if a > 100 or b > 15:
    print("at least one true")
if not a > 50:
    print("negation true")
if a > 5 and b > 10 or a < 20:
    print("complex expression true")
temp = 25
if 20 <= temp <= 30:
    print("comfortable temperature")
fruits = ["apple", "banana"]
if "apple" in fruits:
    print("apple found")
if "grape" not in fruits:
    print("grape not found")
val = None
if val is None:
    print("val is None")
if val is not None:
    print("val is not None")
else:
    print("val is None")
