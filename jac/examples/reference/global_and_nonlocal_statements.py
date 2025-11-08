x = "Jaclang "


def outer_func() -> None:
    global x
    x = "Jaclang is "
    y = "Awesome"

    def inner_func() -> tuple[str, str]:
        nonlocal y
        y = "Fantastic"
        return (x, y)

    print(x, y)
    print(inner_func())


outer_func()
