# 1. Simple iteration
with entry {
    for x in [1, 2, 3] {
        print(x);
    }
}

# 2. Tuple unpacking
glob items = [(1, 2), (3, 4), (5, 6)];
with entry {
    for (a, b) in items {
        print(a, b);
    }
}

# 3. List unpacking
glob items = [[1, 2, 3], [4, 5, 6]];
with entry {
    for [a, b, c] in items {
        print(a, b, c);
    }
}

# 4. Mixed tuple/list unpacking
glob items = [('a', [1, 2]), ('b', [3, 4])];
with entry {
    for (name, [x, y]) in items {
        print(name, x, y);
    }
}

# 5. Star in middle
glob items = [(1, 2, 3, 4, 5), (6, 7, 8, 9, 10)];
with entry {
    for (first, *middle, last) in items {
        print(first, middle, last);
    }
}

# 6. Deep nesting
glob items = [(1, (2, (3, 4))), (5, (6, (7, 8)))];
with entry {
    for (a, (b, (c, d))) in items {
        print(a, b, c, d);
    }
}
