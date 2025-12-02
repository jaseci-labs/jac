"""Collection values: Lists, tuples, dicts, sets, and comprehensions."""

with entry {
    # Literals
    lst = [1, 2, 3];
    tpl = (1, 2, 3);
    dct = {"a": 1, "b": 2};
    st = {1,2,3};

    # Empty collections
    empty_lst = [];
    empty_dct = {};
    empty_tpl = ();

    # List comprehension
    squares = [x ** 2 for x in range(5)];
    filtered = [
        x
        for x in range(10)
        if x % 2 == 0
    ];

    # Dict comprehension
    dict_comp = {x: x ** 2 for x in range(5)};

    # Set comprehension
    set_comp = {x ** 2 for x in range(5)};

    # Generator comprehension
    gen_comp = (x ** 2 for x in range(5));

    # Multiple loops/filters
    multi = [x * y for x in [1, 2] for y in [3, 4]];
    multi_if = [
        x
        for x in range(20)
        if x % 2 == 0
        if x % 3 == 0
    ];

    # Nested comprehensions
    matrix = [[i * j for j in range(3)] for i in range(3)];

    # Dictionary unpacking
    merged = {** dct, "c": 3};

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
