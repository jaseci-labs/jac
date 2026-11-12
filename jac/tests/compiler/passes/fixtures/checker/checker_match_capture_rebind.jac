def checked(v: str | int, w: float | int, flag: bool) {
    n = 0;
    match v {
        case str() as n:
            print(n);

    }
    match w {
        case float() if flag:
            print(w);

        case n:
            print(n);

    }
    match v {
        case str("x"):
            print(v);

        case n:
            print(n);

    }
}

def unchecked(v: str | int | None, xs: list[int] | int) {
    n = 0;
    match v {
        case None:
            print(v);

        case str():
            print(v);

        case n:
            print(n);

    }
    match xs {
        case [ * items ]:
            print(items);

        case n:
            print(n);

    }
    match v {
        case int() as fresh:
            print(fresh);

    }
}
