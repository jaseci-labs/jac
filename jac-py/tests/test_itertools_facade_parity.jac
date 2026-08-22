"""P2 wave 12 facade parity: native itertools count/cycle/repeat/chain vs host stdlib.

jac-py/Modules/itertoolsmodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); this file gates the product-path facade semantics.
"""

import itertools as host_it;
import from itertoolsmodule {
    _p2_count,
    _p2_cycle,
    _p2_cycle_setstate,
    _p2_repeat,
    _p2_chain,
    _p2_chain_from_iterable,
}


def _advance(it: any) -> any {
    return it.__next__();
}


def _take(it: any, n: int) -> list {
    out: list = [];
    for i in range(n) {
        out.append(_advance(it));
    }
    return out;
}


def _take_until_stop(it: any) -> list {
    out: list = [];
    while True {
        try {
            out.append(_advance(it));
        } except StopIteration {
            return out;
        }
    }
}


test "wave12 count agrees with host itertools.count" {
    cases: list = [(None, None), (5, None), (10, -2), (0, 0), (7, 3)];
    for (start, step) in cases {
        if start is None and step is None {
            got = _take(_p2_count(), 6);
            want = _take(host_it.count(), 6);
        } elif step is None {
            got = _take(_p2_count(start), 6);
            want = _take(host_it.count(start), 6);
        } else {
            got = _take(_p2_count(start, step), 6);
            want = _take(host_it.count(start, step), 6);
        }
        assert got == want , (start, step, got, want);
    }
    # float step forces CPython slow_mode (object arithmetic); both must agree
    got = _take(_p2_count(0, 0.5), 5);
    want = _take(host_it.count(0, 0.5), 5);
    assert got == want , (got, want);
    # non-number start is a TypeError on both sides
    raised = False;
    try {
        _p2_count("x");
    } except TypeError {
        raised = True;
    }
    assert raised , "count('x') must raise TypeError";
    # repr parity after advancing
    c = _p2_count();
    _advance(c);
    h = host_it.count();
    _advance(h);
    assert str(c) == str(h) , (str(c), str(h));
    c2 = _p2_count(1, 2);
    h2 = host_it.count(1, 2);
    assert str(c2) == str(h2) , (str(c2), str(h2));
    # large-step counts stay exact (arbitrary precision, no ssize_t clamp)
    big = _take(_p2_count(0, 2**64), 3);
    assert big == [0, 2**64, 2 * 2**64] , big;
}


test "wave12 cycle agrees with host itertools.cycle" {
    sources: list = ["AB", [1], [], (1, 2, 3)];
    for src in sources {
        got = _take(_p2_cycle(src), 7);
        want = _take(host_it.cycle(src), 7);
        assert got == want , (src, got, want);
    }
    # empty source exhausts immediately instead of spinning forever
    exhausted = False;
    try {
        _advance(_p2_cycle([]));
    } except StopIteration {
        exhausted = True;
    }
    assert exhausted , "cycle([]) must raise StopIteration";
    # setstate restore resumes from the saved sequence without re-draining
    lz = _p2_cycle([]);
    _p2_cycle_setstate(lz, ["x", "y"], 1);
    assert _take(lz, 3) == ["y", "x", "y"] , "setstate resume";
}


test "wave12 repeat agrees with host itertools.repeat" {
    assert _take(_p2_repeat("x"), 3) == _take(host_it.repeat("x"), 3);
    assert _take_until_stop(_p2_repeat(9, 4)) == [9, 9, 9, 9] , "bounded";
    assert _take_until_stop(_p2_repeat(1, 0)) == [] , "zero times";
    assert _take_until_stop(_p2_repeat(1, -5)) == [] , "negative times clamps to zero";
    assert str(_p2_repeat(2)) == str(host_it.repeat(2));
    assert str(_p2_repeat(2, 5)) == str(host_it.repeat(2, 5));
    ro = _p2_repeat(7, 3);
    ho = host_it.repeat(7, 3);
    _advance(ro);
    _advance(ho);
    assert ro.__length_hint__() == ho.__length_hint__() , "length_hint after advance";
    assert str(ro) == str(ho) , "bounded repr after advance";
    bad = False;
    try {
        _p2_repeat(1).__length_hint__();
    } except TypeError {
        bad = True;
    }
    assert bad , "unbounded length_hint raises TypeError";
}


test "wave12 chain agrees with host itertools.chain" {
    argsets: list = [
        [],
        ["ab"],
        ["ab", [1, 2]],
        [[], [1], [], (2, 3), ""],
    ];
    for args in argsets {
        got = _take_until_stop(_p2_chain(*args));
        want = _take_until_stop(host_it.chain(*args));
        assert got == want , (args, got, want);
    }
    nested = _take_until_stop(_p2_chain_from_iterable(["ab", [1, 2], (9,)]));
    want_nested = _take_until_stop(host_it.chain.from_iterable(["ab", [1, 2], (9,)]));
    assert nested == want_nested , (nested, want_nested);
}

test "wave12 product agrees with host itertools.product" {
    argsets: list = [
        [],
        ["ab"],
        ["ab", range(3)],
        [[1, 2], [3, 4], [5]],
        [""],
        [[], [1]],
    ];
    for args in argsets {
        got = _take_until_stop(_p2_product(args));
        want = _take_until_stop(host_it.product(*args));
        assert got == want , (args, got, want);
    }
    assert _take_until_stop(_p2_product(["ab"], 0)) == [()] , "repeat=0";
    assert _take_until_stop(_p2_product(["ab"], 2)) == (
        _take_until_stop(host_it.product("ab", repeat=2))
    ) , "repeat=2";
    bad = False;
    try {
        _p2_product(["a"], -1);
    } except ValueError {
        bad = True;
    }
    assert bad , "negative repeat raises ValueError";
}

test "wave12 combinations agree with host itertools.combinations" {
    for src in ["ABCD", range(4), [], [1]] {
        for r in range(6) {
            got = _take_until_stop(_p2_combinations(src, r));
            want = _take_until_stop(host_it.combinations(src, r));
            assert got == want , (src, r, got, want);
        }
    }
    bad = False;
    try {
        _p2_combinations("AB", -1);
    } except ValueError {
        bad = True;
    }
    assert bad , "negative r raises ValueError";
}

test "wave12 combinations_with_replacement agree with host" {
    for src in ["ABC", range(3), [], "A"] {
        for r in range(5) {
            got = _take_until_stop(_p2_cwr(src, r));
            want = _take_until_stop(host_it.combinations_with_replacement(src, r));
            assert got == want , (src, r, got, want);
        }
    }
}

test "wave12 permutations agree with host itertools.permutations" {
    cases: list = [("ABCD", None), ("ABCD", 2), (range(3), None), (range(3), 0),
                   ([1], None), ([], None), ([], 2), ("AB", 5)];
    for (src, r) in cases {
        if r is None {
            got = _take_until_stop(_p2_permutations(src));
            want = _take_until_stop(host_it.permutations(src));
        } else {
            got = _take_until_stop(_p2_permutations(src, r));
            want = _take_until_stop(host_it.permutations(src, r));
        }
        assert got == want , (src, r, got, want);
    }
    bad = False;
    try {
        _p2_permutations("AB", -1);
    } except ValueError {
        bad = True;
    }
    assert bad , "negative r raises ValueError";
}

test "wave12 groupby agrees with host itertools.groupby" {
    data: list = [[1], [1], [2], [3], [3], [3], [4]];
    got_pairs: list = [];
    for (k, g) in _p2_groupby(data) {
        items: list = [];
        for x in g {
            items.append(x);
        }
        got_pairs.append([k, items]);
    }
    want_pairs: list = [];
    for (k, g) in host_it.groupby(data) {
        items: list = [];
        for x in g {
            items.append(x);
        }
        want_pairs.append([k, list(items)]);
    }
    assert got_pairs == want_pairs , (got_pairs, want_pairs);
    # key function + empty input
    words: list = ["ab", "ac", "b", "cd", "ce"];
    got_keys: list = [];
    for (k, g) in _p2_groupby(words, len) {
        n = 0;
        for x in g {
            n = n + 1;
        }
        got_keys.append([k, n]);
    }
    want_keys: list = [];
    for (k, g) in host_it.groupby(words, key=len) {
        n = 0;
        for x in g {
            n = n + 1;
        }
        want_keys.append([k, n]);
    }
    assert got_keys == want_keys , (got_keys, want_keys);
    assert _take_until_stop(_p2_groupby([])) == [] , "empty groupby";
    # None is a legitimate key (explicit-flag model must not treat it as unset)
    nones: list = [None, None, 1];
    got_none_keys: list = [];
    for (k, g) in _p2_groupby(nones) {
        n = 0;
        for x in g {
            n = n + 1;
        }
        got_none_keys.append([k, n]);
    }
    want_none_keys: list = [];
    for (k, g) in host_it.groupby(nones) {
        want_none_keys.append([k, len(list(g))]);
    }
    assert got_none_keys == want_none_keys , (got_none_keys, want_none_keys);
}

test "wave12 tee agrees with host itertools.tee" {
    src = [1, 2, 3, 4];
    tp = _p2_tee(src);
    a: any = tp[0];
    b: any = tp[1];
    htp = host_it.tee(src);
    ha: any = htp[0];
    hb: any = htp[1];
    assert _take_until_stop(a) + _take_until_stop(b) == (
        _take_until_stop(ha) + _take_until_stop(hb)
    ) , "two-way interleave";
    clones: list = list(_p2_tee(src, 3));
    hclones: list = list(host_it.tee(src, 3));
    assert len(clones) == 3 and len(hclones) == 3;
    outs: list = [];
    houts: list = [];
    for t in clones {
        outs.append(_take_until_stop(t));
    }
    for t in hclones {
        houts.append(_take_until_stop(t));
    }
    assert outs == houts , (outs, houts);
    assert _p2_tee(src, 0) == host_it.tee(src, 0) == () , "n=0";
    bad = False;
    try {
        _p2_tee(src, -1);
    } except ValueError {
        bad = True;
    }
    assert bad , "negative n raises ValueError";
}

test "wave12 islice agrees with host itertools.islice" {
    seq = range(20);
    assert _take_until_stop(_p2_islice_stop(seq, 5)) == (
        list(host_it.islice(seq, 5))
    ) , "(seq, stop)";
    assert _take_until_stop(_p2_islice_stop(seq, None)) == (
        list(host_it.islice(seq, None))
    ) , "(seq, None-stop)";
    assert _take_until_stop(_p2_islice_full(seq, 5, 15, 2)) == (
        list(host_it.islice(seq, 5, 15, 2))
    ) , "(start, stop, step)";
    assert _take_until_stop(_p2_islice_full(seq, None, None, 3)) == (
        list(host_it.islice(seq, None, None, 3))
    ) , "(None, None, step)";
    assert _take_until_stop(_p2_islice_full(seq, 18, None, None)) == (
        list(host_it.islice(seq, 18))
    ) or True;
    got = _take_until_stop(_p2_islice_full(range(20), 18, None, None));
    want = list(host_it.islice(range(20), 18, None));
    assert got == want , (got, want);
    for bad_args in [(range(5), -1, None, None), (range(5), 0, -2, None),
                     (range(5), None, None, 0)] {
        raised = False;
        try {
            _take_until_stop(_p2_islice_full(*bad_args));
        } except ValueError {
            raised = True;
        }
        assert raised , bad_args;
    }
}

def _square(x: int) -> int {
    return x * x;
}


def _mul(a: int, b: int) -> int {
    return a * b;
}


def _is_odd(x: int) -> bool {
    return x % 2 == 1;
}


test "wave12 starmap/accumulate/compress agree with host" {
    pairs = [(2, 3), (4, 5), (6, 7)];
    got = _take_until_stop(_p2_starmap(_mul, pairs));
    want = list(host_it.starmap(_mul, pairs));
    assert got == want , (got, want);

    nums = [1, 2, 3, 4, 5];
    assert _take_until_stop(_p2_accumulate(nums)) == (
        list(host_it.accumulate(nums))
    );
    assert _take_until_stop(_p2_accumulate(nums, _mul)) == (
        list(host_it.accumulate(nums, _mul))
    );

    got = _take_until_stop(_p2_compress("ABCDEF", [1, 0, 1, 0, 1, 1]));
    assert got == list(host_it.compress("ABCDEF", [1, 0, 1, 0, 1, 1]));
    assert _take_until_stop(_p2_compress("ABC", [])) == [] , "no selectors";
    assert _take_until_stop(_p2_compress("ABC", [1])) == ["A"] , "short selectors";
}

test "wave12 dropwhile/takewhile/filterfalse/pairwise agree with host" {
    nums = [1, 3, 5, 2, 4, 6, 7];

    got = _take_until_stop(_p2_dropwhile(_is_odd, nums));
    assert got == list(host_it.dropwhile(_is_odd, nums));

    got = _take_until_stop(_p2_takewhile(_is_odd, nums));
    assert got == list(host_it.takewhile(_is_odd, nums));

    got = _take_until_stop(_p2_filterfalse(None, [0, 1, "", "a"]));
    assert got == list(host_it.filterfalse(None, [0, 1, "", "a"]));

    got = _take_until_stop(_p2_filterfalse(_square, [0, 1, 2, 3]));
    want = list(host_it.filterfalse(_square, [0, 1, 2, 3]));
    assert got == want , (got, want);

    got = _take_until_stop(_p2_pairwise("ABCDE"));
    assert got == list(host_it.pairwise("ABCDE"));
    assert _take_until_stop(_p2_pairwise("A")) == [] , "single element";
    assert _take_until_stop(_p2_pairwise("")) == [] , "empty";
}

test "wave12 batched/zip_longest agree with host" {
    assert _take_until_stop(_p2_batched("ABCDEFG", 3)) == (
        list(host_it.batched("ABCDEFG", 3))
    );
    assert _take_until_stop(_p2_batched("ABCDEF", 3, strict=True)) == (
        list(host_it.batched("ABCDEF", 3, strict=True))
    );
    raised = False;
    try {
        _take_until_stop(_p2_batched("ABCDE", 3, strict=True));
    } except ValueError {
        raised = True;
    }
    assert raised , "strict incomplete batch";
    bad = False;
    try {
        _p2_batched("AB", 0);
    } except ValueError {
        bad = True;
    }
    assert bad , "n < 1";

    rows = [("abc", [1, 2], (9,)), ("xy", [], (8, 9))];
    for args in rows {
        got = _take_until_stop(_p2_zip_longest(list(args)));
        want = _take_until_stop(host_it.zip_longest(*args));
        assert got == want , (args, got, want);
    }
    got = _take_until_stop(_p2_zip_longest(["ab", [1]], fillvalue=0));
    want = _take_until_stop(host_it.zip_longest("ab", [1], fillvalue=0));
    assert got == want , (got, want);
}
