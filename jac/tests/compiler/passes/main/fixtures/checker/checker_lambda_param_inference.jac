with entry {
    rows: list[dict[str, int]] = [{"n": 2}, {"n": 1}];
    by_key = sorted(rows, key=lambda d : d["n"]);

    nums: list[int] = [3, 1, 2];
    descending = sorted(nums, key=lambda x : -x);
    biggest = max(nums, key=lambda x : x );
    smallest = min(nums, key=lambda x : x );

    words: list[str] = ["bb", "a", "ccc"];
    by_len = sorted(words, key=lambda s : len(s));
    only_long = list(filter(lambda s : len(s) > 1, words));

    # Operators, subscripts, and method/attr access on the inferred param.
    arithmetic = sorted(nums, key=lambda x : x * 2 - 1);
    captured_bias: int = 10;
    with_capture = sorted(nums, key=lambda x : x + captured_bias);
    dict_arith = sorted(rows, key=lambda d : d["n"] + 1);
    by_upper = sorted(words, key=lambda s : s.upper());

    print(
        by_key,
        descending,
        biggest,
        smallest,
        by_len,
        only_long,
        arithmetic,
        with_capture,
        dict_arith,
        by_upper
    );
}
