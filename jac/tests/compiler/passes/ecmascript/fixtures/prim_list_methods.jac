"""List method primitives: append, extend, insert, pop, clear, index, reverse, copy."""

def list_methods_py() -> dict {
    # append
    a1: list = [1, 2, 3];
    a1.append(4);

    # extend
    a2: list = [1, 2];
    a2.extend([3, 4, 5]);

    # insert
    a3: list = [1, 3, 4];
    a3.insert(1, 2);

    # pop (no arg - removes last)
    a4: list = [10, 20, 30];
    popped_last: int = a4.pop();

    # pop (with index)
    a5: list = [10, 20, 30];
    popped_first: int = a5.pop(0);

    # clear
    a6: list = [1, 2, 3];
    a6.clear();

    # index
    a7: list = [10, 20, 30, 20];
    idx: int = a7.index(20);

    # reverse
    a8: list = [3, 1, 2];
    a8.reverse();

    # copy
    a9: list = [1, 2, 3];
    a9_copy: list = a9.copy();

    return {
        "after_append": a1,
        "after_extend": a2,
        "after_insert": a3,
        "popped_last": popped_last,
        "after_pop_last": a4,
        "popped_first": popped_first,
        "after_pop_first": a5,
        "after_clear": a6,
        "index": idx,
        "after_reverse": a8,
        "copy": a9_copy
    };
}

cl def list_methods_cl() -> dict {
    # append
    a1: list = [1, 2, 3];
    a1.append(4);

    # extend
    a2: list = [1, 2];
    a2.extend([3, 4, 5]);

    # insert
    a3: list = [1, 3, 4];
    a3.insert(1, 2);

    # pop (no arg - removes last)
    a4: list = [10, 20, 30];
    popped_last: int = a4.pop();

    # pop (with index)
    a5: list = [10, 20, 30];
    popped_first: int = a5.pop(0);

    # clear
    a6: list = [1, 2, 3];
    a6.clear();

    # index
    a7: list = [10, 20, 30, 20];
    idx: int = a7.index(20);

    # reverse
    a8: list = [3, 1, 2];
    a8.reverse();

    # copy
    a9: list = [1, 2, 3];
    a9_copy: list = a9.copy();

    return {
        "after_append": a1,
        "after_extend": a2,
        "after_insert": a3,
        "popped_last": popped_last,
        "after_pop_last": a4,
        "popped_first": popped_first,
        "after_pop_first": a5,
        "after_clear": a6,
        "index": idx,
        "after_reverse": a8,
        "copy": a9_copy
    };
}
