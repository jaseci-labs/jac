# Control Statements

# Break - exits loop
with entry {
    for i in range(10) {
        if i > 3 {
            break;
        }
        print(i);
    }

    # Continue - skips to next iteration
    for j in range(5) {
        if j == 2 {
            continue;
        }
        print(j);
    }
}

# Break in while loop
glob count = 0;

with entry {
    while True {
        count += 1;
        if count > 3 {
            break;
        }
        print(count);
    }
}

# Continue in while loop
glob n = 0;

with entry {
    while n < 5 {
        n += 1;
        if n % 2 == 0 {
            continue;
        }
        print(n);
    }
}

# Skip (Jac-specific, used in walker contexts)
walker SkipWalker {
    can process with entry {
        skip;
    }
}

# Nested loops with break
with entry {
    for x in range(3) {
        for y in range(3) {
            if x == y == 1 {
                break;
            }
            print(f"{x},{y}");
        }
    }

    # Nested loops with continue
    for a in range(3) {
        for b in range(3) {
            if a == b {
                continue;
            }
            print(f"{a},{b}");
        }
    }
}
