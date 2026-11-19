def seven -> int {
    return 7;
}

def call0(f: Callable) -> int {
    return f() + 1;
}

with entry {
    print(call0(seven));
}
