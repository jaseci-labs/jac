def seven -> int {
    return 7;
}

def opt_call_local(f: Callable | None) -> int {
    if f is not None {
        return f();
    }
    return 0;
}

with entry {
    print(opt_call_local(seven));
    print(opt_call_local(None));
}
