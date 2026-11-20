with entry {
    i = 0;
    forever {
        i += 1;
        print("Iter: ", i);
        if i >= 3 {
            break;
        }
    }
    print("Done: ", i);

    # `continue` inside forever skips odd numbers.
    total = 0;
    n = 0;
    forever {
        n += 1;
        if n > 10 {
            break;
        }
        if n % 2 == 1 {
            continue;
        }
        total += n;
    }
    print("Sum: ", total);

    # Nested forever: inner break only exits the inner loop.
    outer = 0;
    forever {
        outer += 1;
        inner = 0;
        forever {
            inner += 1;
            if inner >= 2 {
                break;
            }
        }
        if outer >= 2 {
            break;
        }
    }
    print("Nested: ", outer, inner);
}
