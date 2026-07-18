# Native fixture: lazy iterator adapters (map / filter / enumerate / zip)
# driven through the iterator protocol in for-loops. Returns ints so tests
# can assert via ctypes.

def double(x: int) -> int {
    return x * 2;
}

def is_even(x: int) -> bool {
    return x % 2 == 0;
}

# map: 2+4+6+8 = 20
def map_sum() -> int {
    total: int = 0;
    for x in map(double, [1, 2, 3, 4]) {
        total = total + x;
    }
    return total;
}

# filter: 2+4+6 = 12
def filter_sum() -> int {
    total: int = 0;
    for x in filter(is_even, [1, 2, 3, 4, 5, 6]) {
        total = total + x;
    }
    return total;
}

# filter with no matches: 0
def filter_empty() -> int {
    total: int = 0;
    for x in filter(is_even, [1, 3, 5]) {
        total = total + x;
    }
    return total;
}

# composition: filter -> 2,4,6 ; map(double) -> 4,8,12 ; sum = 24
def compose_sum() -> int {
    total: int = 0;
    for x in map(double, filter(is_even, [1, 2, 3, 4, 5, 6])) {
        total = total + x;
    }
    return total;
}

# break mid-map: double -> 2,4,6,... ; stop when x == 6 ; sum = 2+4 = 6
def map_break() -> int {
    total: int = 0;
    for x in map(double, [1, 2, 3, 4, 5]) {
        if x == 6 {
            break;
        }
        total = total + x;
    }
    return total;
}

# enumerate: (0,10),(1,20),(2,30) -> 10 + 120 + 230 = 360
def enum_sum() -> int {
    total: int = 0;
    for (i, x) in enumerate([10, 20, 30]) {
        total = total + i * 100 + x;
    }
    return total;
}

# zip equal lengths: 1*10 + 2*20 + 3*30 = 140
def zip_sum() -> int {
    total: int = 0;
    for (a, b) in zip([1, 2, 3], [10, 20, 30]) {
        total = total + a * b;
    }
    return total;
}

# zip unequal lengths stops at shorter: 1*10 + 2*20 = 50
def zip_unequal() -> int {
    total: int = 0;
    for (a, b) in zip([1, 2, 3, 4], [10, 20]) {
        total = total + a * b;
    }
    return total;
}

with entry {}
