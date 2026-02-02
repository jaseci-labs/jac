def greet() -> str {
    return "hello";
}

def concat_strings(a: str, b: str) -> str {
    return a + b;
}

def str_equal(a: str, b: str) -> int {
    if a == b {
        return 1;
    }
    return 0;
}

def str_not_equal(a: str, b: str) -> int {
    if a != b {
        return 1;
    }
    return 0;
}

def format_int(n: int) -> str {
    return f"val={n}";
}

def format_two(a: int, b: int) -> str {
    return f"{a}+{b}";
}

def format_mixed(name: str, age: int) -> str {
    return f"name={name}, age={age}";
}
