def while_result -> int {
    again = True;
    values = [0];
    while again {
        values = [42];
        again = False;
    }
    return values[0];
}

def for_result -> int {
    values = [0];
    for number in range(1, 4) {
        values = [number];
    }
    return values[0];
}

def nested_result -> int {
    values = [0];
    total = 0;
    for outer in range(2) {
        for inner in range(2) {
            values = [outer + inner];
        }
        total = values[0];
    }
    return total;
}
