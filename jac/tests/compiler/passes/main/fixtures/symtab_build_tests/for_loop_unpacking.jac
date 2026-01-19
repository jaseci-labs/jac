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

# 4. Nested tuple unpacking
glob items = [('alice', (10, 20)), ('bob', (30, 40))];
with entry {
    for (name, (x, y)) in items {
        print(name, x, y);
    }
}

# 5. Nested list unpacking
glob items = [['a', ['b', 'c']], ['d', ['e', 'f']]];
with entry {
    for [x, [y, z]] in items {
        print(x, y, z);
    }
}

# 6. Mixed tuple/list unpacking
glob items = [('a', [1, 2]), ('b', [3, 4])];
with entry {
    for (name, [x, y]) in items {
        print(name, x, y);
    }
}

# 7. Star unpacking
glob items = [(1, 2, 3, 4), (5, 6, 7, 8)];
with entry {
    for (a, b, *rest) in items {
        print(a, b, rest);
    }
}

# 8. Star in middle
glob items = [(1, 2, 3, 4, 5), (6, 7, 8, 9, 10)];
with entry {
    for (first, *middle, last) in items {
        print(first, middle, last);
    }
}

# 9. Deep nesting
glob items = [(1, (2, (3, 4))), (5, (6, (7, 8)))];
with entry {
    for (a, (b, (c, d))) in items {
        print(a, b, c, d);
    }
}

# 10. Dictionary items
glob d = {'a': 1, 'b': 2, 'c': 3};
with entry {
    for (key, value) in d.items() {
        print(key, value);
    }
}

# 11. Enumerate with unpacking
glob items = [(10, 20), (30, 40)];
with entry {
    for (i, (a, b)) in enumerate(items) {
        print(i, a, b);
    }
}

# 12. Zip with unpacking
glob xs = [1, 2, 3],
     ys = [10, 20, 30];

with entry {
    for (x, y) in zip(xs, ys) {
        print(x, y);
    }
}

# 13. Complex: enumerate + zip + unpacking
glob xs = [1, 2, 3],
     ys = [10, 20, 30],
     zs = [100, 200, 300];

with entry {
    for (i, (a, b, c)) in enumerate(zip(xs, ys, zs)) {
        print(i, a, b, c);
    }
}
