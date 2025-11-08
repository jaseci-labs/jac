def foo(x: int, y: int, z: int) -> tuple[int, int]:
    return (x * y, y * z)


a = 5
output = foo(x=4, y=4 if a % 3 == 2 else 3, z=9)
print(output)
