def foo(value: int):
    if value < 0:
        raise ValueError("Value must be non-negative")


try:
    foo(-1)
except ValueError as e:
    print("Raised:", e)
