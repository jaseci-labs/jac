"""A loop's else runs after that loop has finished, so a break or continue in it
belongs to the enclosing loop, as in Python."""

with entry {
    total = 0;
    for outer in range(3) {
        while False {} else {
            total += 1;
            if outer == 1 {
                break;
            }
            total += 10;
        }
        total += 100;
    } else {
        total += 1000;
    }
    assert total == 112;
}

glob rows: list[list[int]] = [];

with entry {
    for row in [[1, 3], [2, 5], [7]] {
        for x in row {
            if x % 2 == 0 {
                break;
            }
        } else {
            continue;
        }
        rows.append(row);
    }
    assert rows == [[2, 5]];

    count = 0;
    for i = 0 while i < 3 with i += 1 {
        for item in [] {} else {
            count += 1;
            continue;
        }
        count += 100;
    }
    assert count == 3;
    print(total, rows, count);
}
