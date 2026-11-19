def name -> str {
    return "probe";
}

def call0(f: Callable) -> str {
    return f() + "!";
}

with entry {
    print(call0(name));
}
