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
