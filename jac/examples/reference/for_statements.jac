# For Statements

# Basic for-in loop
with entry {
    for x in [1, 2, 3] {
        print(x);
    }

    # For-in with range
    for i in range(5) {
        print(i);
    }

    # For-to-by loop
    for i = 0 to i < 5 by i += 1 {
        print(i);
    }

    # For-to-by counting down
    for i = 10 to i > 0 by i -= 1 {
        print(i);
    }

    # For-to-by with different step
    for i = 0 to i < 10 by i += 2 {
        print(i);
    }

    # For with else clause (executes when loop completes normally)
    for x in [1, 2, 3] {
        print(x);
    } else {
        print("completed");
    }

    # For with break (else clause skipped)
    for x in range(10) {
        if x == 3 {
            break;
        }
        print(x);
    } else {
        print("not reached");
    }

    # For with continue
    for x in range(5) {
        if x % 2 == 0 {
            continue;
        }
        print(x);
    }

    # Nested for loops
    for i in range(3) {
        for j in range(2) {
            print(f"{i},{j}");
        }
    }

    # For-in over string
    for char in "abc" {
        print(char);
    }
}

# For-in over dictionary keys
glob d = {"a": 1, "b": 2};

with entry {
    for key in d {
        print(key);
    }

    # Mix for-in and for-to-by in nested loops
    for i in ["a", "b"] {
        for j = 0 to j < 2 by j += 1 {
            print(f"{i}{j}");
        }
    }
}

# Tuple unpacking
glob pairs = [(1, 2), (3, 4), (5, 6)];

with entry {
    for (a, b) in pairs {
        print(f"a={a}, b={b}");
    }
}

# List unpacking (uses tuple syntax in Jac)
glob matrix = [[1, 2, 3], [4, 5, 6]];

with entry {
    for (x, y, z) in matrix {
        print(f"x={x}, y={y}, z={z}");
    }
}

# Nested tuple unpacking
glob nested = [("alice", (10, 20)), ("bob", (30, 40))];

with entry {
    for (name, (x, y)) in nested {
        print(f"{name}: x={x}, y={y}");
    }
}

# Star unpacking (rest of elements)
glob items = [(1, 2, 3, 4), (5, 6, 7, 8)];

with entry {
    for (first, *rest) in items {
        print(f"first={first}, rest={rest}");
    }
}

# Star unpacking in middle
glob sequences = [(1, 2, 3, 4, 5), (6, 7, 8, 9, 10)];

with entry {
    for (first, *middle, last) in sequences {
        print(f"first={first}, middle={middle}, last={last}");
    }
}

# Dictionary items unpacking
glob data = {
         "name": "Alice",
         "age": 30,
         "city": "NYC"
     };

with entry {
    for (key, value) in data.items() {
        print(f"{key}: {value}");
    }
}

# Enumerate with unpacking
glob coords = [(10, 20), (30, 40), (50, 60)];

with entry {
    for (i, (x, y)) in enumerate(coords) {
        print(f"Point {i}: ({x}, {y})");
    }
}

# Zip with unpacking
glob xs = [1, 2, 3],
     ys = [10, 20, 30];

with entry {
    for (x, y) in zip(xs, ys) {
        print(f"x={x}, y={y}");
    }
}

# Complex: enumerate + zip + unpacking
glob as_ = [1, 2, 3],
     bs = [4, 5, 6],
     cs = [7, 8, 9];

with entry {
    for (i, (a, b, c)) in enumerate(zip(as_, bs, cs)) {
        print(f"Index {i}: a={a}, b={b}, c={c}");
    }
}
