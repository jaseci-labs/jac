"""A break in a loop else exits that suite, including inside an outer loop."""

with entry {
    total = 0;
    for outer in range(3) {
        while False {} else {
            total += 1;
            if True {
                break;
            }
            total += 1000;
        }
        for item in [] {} else {
            total += 10;
            if total > 0 {
                break;
            }
            total += 1000;
        }
        for i = 0 while i < 0 with i += 1 {} else {
            total += 100;
            if total > 0 {
                break;
            }
            total += 1000;
        }
    } else {
        total += 1000;
    }
    assert total == 1333;

    # No enclosing loop: Python must still compile the break.
    while False {} else {
        for inner in range(3) {
            if inner == 0 {
                continue;
            }
            total += 1;
            break;
        }
        total += 10;
        try {
            break;
        } finally {
            total += 100;
        }
        total += 1000;
    }
    assert total == 1444;
    print(total);
}
