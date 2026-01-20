# 1. Simple
glob result1 = [x * 2 for x in [1, 2, 3]];

# 2. Tuple unpacking
glob items2 = [(1, 2), (3, 4), (5, 6)],
     result2 = [(a + b) for (a, b) in items2];

# 3. Nested tuple unpacking
glob items3 = [('alice', (10, 20)), ('bob', (30, 40))],
     result3 = [name for (name, (x, y)) in items3];

# 4. Star unpacking
glob items4 = [(1, 2, 3, 4), (5, 6, 7, 8)],
     result4 = [a for (a, b, *rest) in items4];

# 5. Deep nesting
glob items5 = [(1, (2, (3, 4))), (5, (6, (7, 8)))],
     result5 = [a for (a, (b, (c, d))) in items5];

# 6. Set comprehension with unpacking
glob items6 = [(1, 2), (3, 4)],
     result6 = {a + b for (a, b) in items6};

# 7. Dict comprehension with unpacking
glob items7 = [(1, 2), (3, 4)],
     result7 = {k: v for (k, v) in items7};

# 8. Generator expression with unpacking
glob items8 = [(1, 2), (3, 4)],
     gen8 = (a + b for (a, b) in items8);

# 9. Nested iteration with unpacking
glob data9 = [
         [('a', 1), ('b', 2)],
         [('c', 3)]
     ],
     result9 = [name for row in data9 for (name, val) in row];
