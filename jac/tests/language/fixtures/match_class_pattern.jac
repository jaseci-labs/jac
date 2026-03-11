def foo(x: object) -> None {
    match x {
        case int():
            print("int");
        case str():
            print("str");
        case _:
            ;
    }
}

with entry {
    foo(42);
    foo("hello");
    foo(3.14);
}
