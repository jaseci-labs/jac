# Match sequence patterns - Pattern matching in match statements

with entry {
    # Exact sequence match
    data = [1, 2, 3];
    match data {
        case [1, 2, 3]:
            print("Matched exact sequence [1, 2, 3]");
        case _:
            print("Not matched");
    }

    # Sequence with variable binding
    seq = [10, 20, 30];
    match seq {
        case [a, b, c]:
            print(f"Matched and captured: a={a}, b={b}, c={c}");
    }

    # Sequence with star pattern (MatchStar) - captures rest
    lst = [1, 2, 3, 4, 5];
    match lst {
        case [first, *middle, last]:
            print(f"First: {first}, middle: {middle}, last: {last}");
    }

    # Star pattern at beginning
    nums = [1, 2, 3, 4];
    match nums {
        case [*start, 4]:
            print(f"Starts with: {start}, ends with 4");
    }

    # Star pattern in middle with specific ends
    values = [10, 20, 30, 40, 50];
    match values {
        case [10, *rest, 50]:
            print(f"Starts with 10, middle: {rest}, ends with 50");
    }

    # Mixed patterns in sequence
    mixed = [1, "hello", 3.14];
    match mixed {
        case [1, str_val, float_val]:
            print(f"Mixed sequence: 1, '{str_val}', {float_val}");
    }
}
