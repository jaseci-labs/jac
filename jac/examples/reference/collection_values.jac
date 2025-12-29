"""Collection values: Lists, tuples, dicts, sets, and comprehensions."""

# Literals
glob lst = [1, 2, 3],
     tpl = (1, 2, 3),
     dct = {"a": 1, "b": 2},
     st = {1,2,3},
     empty_lst = [],
     empty_dct = {},
     empty_tpl = (),
     squares = [x ** 2 for x in range(5)],
     filtered = [
         x
         for x in range(10)
         if x % 2 == 0
     ],
     dict_comp = {x: x ** 2 for x in range(5)},
     set_comp = {x ** 2 for x in range(5)},
     gen_comp = (x ** 2 for x in range(5)),
     multi = [x * y for x in [1, 2] for y in [3, 4]],
     multi_if = [
         x
         for x in range(20)
         if x % 2 == 0
         if x % 3 == 0
     ],
     matrix = [[i * j for j in range(3)] for i in range(3)],
     merged = {** dct, "c": 3};

with entry {
    print(
        lst,
        tpl,
        dct,
        st,
        squares,
        dict_comp,
        set_comp,
        list(gen_comp),
        multi,
        multi_if,
        matrix,
        merged
    );
}
# Empty collections

# List comprehension

# Dict comprehension

# Set comprehension

# Generator comprehension

# Multiple loops/filters

# Nested comprehensions

# Dictionary unpacking
