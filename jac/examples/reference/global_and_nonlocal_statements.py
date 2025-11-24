from __future__ import annotations

x = "global x"
a = 1
b = 2


def test_global() -> None:
    global x
    x = "modified global x"
    print(x)


def test_multiple_globals() -> None:
    global a
    global b
    a = 10
    b = 20
    print(f"{a} {b}")


def outer() -> None:
    y = "outer y"

    def inner() -> None:
        nonlocal y
        y = "modified by inner"
        print(y)

    print(y)
    inner()
    print(y)


def outer_multi() -> None:
    p = 1
    q = 2
    r = 3

    def inner_multi() -> None:
        nonlocal p
        nonlocal q
        nonlocal r
        p = 10
        q = 20
        r = 30

    print(f"{p} {q} {r}")
    inner_multi()
    print(f"{p} {q} {r}")


print(x)
test_global()
print(x)
print(f"{a} {b}")
test_multiple_globals()
print(f"{a} {b}")
outer()
outer_multi()
