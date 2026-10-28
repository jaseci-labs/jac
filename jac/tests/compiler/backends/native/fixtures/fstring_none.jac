def run_cases {
    print("start");
    n = None;
    print(f"{n}");
    print(f"x{n}y");
    print(f"{n!r}");
    print(f"{None!r:>6}");
    print(f"{None}");
    print(f"{None:>6}");
    s: (str | None) = None;
    print(f"{s}");
    print(f"{n!s}");
    print(f"{None!s:>6}");
    q = "t";
    print(f"{q and 'u'}");
    print(f"{n and 'u'}");
    print(f"{n and f'{1}'}");
    print(f"{(n and 'u'):>6}|");
    print("end");
}

with entry {
    run_cases();
}
