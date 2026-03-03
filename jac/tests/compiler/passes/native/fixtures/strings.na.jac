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

# str.replace with count=1 must replace only the first occurrence
def str_replace_first_only(s: str) -> str {
    return s.replace("a", "X", 1);
}

# for c in str: collect chars by appending — tests string iteration codegen
def str_for_in_join(s: str) -> str {
    result: str = "";
    for c in s {
        result = result + c;
    }
    return result;
}

# for c in str: count characters
def str_for_in_count(s: str) -> int {
    n: int = 0;
    for c in s {
        n = n + 1;
    }
    return n;
}
