# 1. List comprehension
glob result1 = [x * 2 for x in [1, 2, 3]];

# 2. Star unpacking
glob star_items = [(1, 2, 3, 4), (5, 6, 7, 8)],
     star_result = [a for (a, b, *rest) in star_items];

# 3. Deep nesting
glob deep_items = [(1, (2, (3, 4))), (5, (6, (7, 8)))],
     deep_result = [a for (a, (b, (c, d))) in deep_items];

# 4. Set comprehension with unpacking
glob set_items = [(1, 2), (3, 4)],
     set_result = {a + b for (a, b) in set_items};

# 5. Dict comprehension with unpacking
glob dict_items = [(1, 2), (3, 4)],
     dict_result = {k: v for (k, v) in dict_items};

# 6. Generator expression with unpacking
glob gen_items = [(1, 2), (3, 4)],
     gen_result = (a + b for (a, b) in gen_items);

# 7. Nested iteration with unpacking
glob nested_data = [
         [('a', 1), ('b', 2)],
         [('c', 3)]
     ],
     nested_result = [name for row in nested_data for (name, val) in row];
