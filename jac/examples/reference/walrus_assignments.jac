# Walrus Assignments

# Walrus in if condition
with entry {
    if (x := 10) > 5 {
        print(f"x = {x}");
    }
}

# Walrus in while condition
glob i = 0,
     data = [1, 2, 3, 4, 5];

with entry {
    while (item := data[i] if i < len(data) else None) and i < 3 {
        print(f"item: {item}");
        i += 1;
    }
}

# Walrus in expression
glob result = (y := 20) + 10;

with entry {
    print(f"y = {y}, result = {result}");

    # Multiple walrus assignments
    if (a := 5) and (b := 10) {
        print(f"a = {a}, b = {b}");
    }
}

# Walrus in function call
def process(value: int) -> int {
    return value * 2;
}

with entry {
    if (z := process(7)) > 10 {
        print(f"z = {z}");
    }
}

# Walrus with complex expression
glob numbers = [1, 2, 3, 4, 5];

with entry {
    if (total := sum(numbers)) > 10 {
        print(f"total = {total}");
    }

    # Walrus in nested context
    if (m := 5) {
        if (n := m * 2) > 8 {
            print(f"m = {m}, n = {n}");
        }
    }
}
