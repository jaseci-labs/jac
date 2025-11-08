def foo(first: int, second: int) -> None:
    print(first, second)


val1 = (3,) + (4,)
val2 = (val1[0] * val1[1], val1[0] + val1[1])


foo(second=val2[1], first=val2[0])
foo(first=val2[0], second=val2[1])
