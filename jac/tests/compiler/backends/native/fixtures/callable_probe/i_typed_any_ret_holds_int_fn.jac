def seven -> int {
    return 7;
}

def call0(f: Callable[[], any]) -> any {
    return f();
}

with entry {
    print(call0(seven));
}
