"""CPython-parity value-semantics tests for the native pathway (issue
#7320, Cluster 2 silent-wrong-value family).

Each fixture exercises an idiom that previously compiled clean on na but
returned a different value than CPython/sv, with results encoded into a
single i64 so a silent divergence fails an equality assert.

Each fixture is compiled once and its functions are checked as one table.
The fixtures' counter globals are reset by the function that reads them,
so the order the functions run in does not matter.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile `fixture`, run its entry block, and return {name: (got, expected)}
for every function in `want` that returned something else."""
def wrong_returns(fixture: str, want: dict[str, int]) -> dict[str, tuple[int, int]] {
    (eng, _) = compile_native(fixture);
    get_func(eng, "jac_entry", None)();
    got = {fn: get_func(eng, fn, ctypes.c_int64)() for fn in want};
    return {
        fn: (got[fn], want[fn])
        for fn in want
        if got[fn] != want[fn]
    };
}

# --- 2a: chained comparisons lower every link, not just the first ---
test "py_chain_cmp: every link is evaluated, the middle one once" {
    wrong = wrong_returns(
        "py_chain_cmp.jac",
        {
            # a=0 (2<3<1), b=1, c=1, d=1, e=0, f=1, g=1
            "chain_cases": 111011,
            # true, one bump
            "middle_evaluated_once": 11,
            # 1<2<3>2
            "long_chain": 1
        }
    );
    assert not wrong , wrong;
}

# --- #7593 item 2: membership/identity links in chains ---
test "py_chain_cmp_mixed: in/is links lower like a single in/is" {
    wrong = wrong_returns(
        "py_chain_cmp_mixed.jac",
        {
            "chain_in_cases": 10111,
            "chain_is_cases": 1001,
            # true, one bump
            "chain_middle_once": 11
        }
    );
    assert not wrong , wrong;
}

# --- 2b: or/and yield the deciding operand value, not a truth bit ---
test "py_bool_ops: or/and return the deciding operand" {
    wrong = wrong_returns(
        "py_bool_ops.jac",
        {
            # 5 or 7 = 5; 0 or 7 = 7; 3 and 9 = 9; 0 and 9 = 0
            "bool_ops_int": 5790,
            # all four str cases pick the right side
            "bool_ops_str": 1111,
            # v=5, w=0, zero bump() calls: rhs not evaluated
            "bool_ops_short_circuit": 500
        }
    );
    assert not wrong , wrong;
}

# --- 2c: membership compares string values, not pointer identity ---
test "py_membership: str in list and d.keys() compares values" {
    wrong = wrong_returns(
        "py_membership.jac",
        {
            # beta found, heap needle found, delta absent, not-in true, 2 in nums
            "str_list_membership": 11011,
            "dict_keys_membership": 110
        }
    );
    assert not wrong , wrong;
}

# --- 2d: sort()/sorted() honor reverse= and key= ---
test "py_sort_kwargs: sort and sorted honour reverse= and key=" {
    wrong = wrong_returns(
        "py_sort_kwargs.jac",
        {
            "sort_reverse": 321,
            # b untouched (3xxx), c descending 321
            "sorted_reverse_copies": 3321,
            # a, dd, ccc
            "sort_key_len": 111,
            # keys mod 10: 5->5, 12->2, 3->3; descending keys: 5, 3, 12
            "sort_key_and_reverse": 50312
        }
    );
    assert not wrong , wrong;
}

# --- dropped-argument family: range step, str search bounds, pow modulus ---
test "py_dropped_args: range step, str search bounds and pow modulus" {
    s = "ab/> cd <img x />";
    wrong = wrong_returns(
        "py_dropped_args.jac",
        {
            # 0,3,6,9 -> 369; 5,3,1 -> 531
            "range_step_sum": 369531,
            # caught ValueError instead of looping
            "range_zero_step_raises": 1,
            # find('b', 2)=4, find('b')=1, find('z', 1)=-1
            "find_with_start": 411,
            "find_bounds_index_from": s.index("/>", 5),
            "find_bounds_find_end": s.find("/>", 0, 3),
            "find_bounds_rfind_window": s.rfind("/>", 0, 6),
            "find_bounds_rindex_window": s.rindex("/>", 0, 6),
            "find_bounds_rfind_from": s.rfind("/>", 5),
            "find_bounds_count_from": s.count("/>", 5),
            "find_bounds_count_window": s.count("/>", 0, 6),
            "find_bounds_negative": s.find("img", -9, -2),
            "find_bounds_empty_past_end": s.find("", 50),
            "find_bounds_empty_start_after_end": s.find("", 6, 2),
            "find_bounds_rfind_empty_window": s.rfind("", 0, 4),
            "find_bounds_count_empty_window": s.count("", 0, 4),
            # s.index("/>", 0, 3) raises ValueError; the fixture maps that to -7
            "find_bounds_index_miss": -7,
            # pow(3,4,5)=1, pow(2,10,1000)=24
            "pow_with_mod": 1024,
            # caught ValueError instead of trapping
            "pow_zero_mod_raises": 1
        }
    );
    assert not wrong , wrong;
}

# --- 2f: f-strings size their buffer and honor format specs ---
test "py_fstring: long output, format specs and !r render like CPython" {
    wrong = wrong_returns(
        "py_fstring.jac",
        {
            # output larger than 1024 bytes is not truncated
            "fstring_long": 1204,
            # .2f, 04d, x, and >4/<4 alignment
            "fstring_specs": 1111,
            # int, float, bool, quote-switching str repr, repr-then-pad ordering
            "fstring_repr": 11111,
            # {w}.{p}f, {w}x, 0{w}d, and *^{w}
            "fstring_dynspec": 1111,
            # an invalid dynamic spec raises ValueError
            "fstring_dynspec_invalid": 1
        }
    );
    assert not wrong , wrong;
}

# --- subscript aug-assign lowers read-modify-write, not an RHS store ---
test "py_subscript_aug: subscript and field aug-assign read-modify-write" {
    wrong = wrong_returns(
        "py_subscript_aug.jac",
        {
            # 7 +=3 ->10, -=2 ->8, *=3 ->24, //=5 ->4, %=3 ->1
            "list_int_ops": 100824041,
            # 17 <<=3 ->136, >>=1 ->68, |=3 ->71, ^=5 ->66, &=31 ->2, **=5 ->32
            "list_int_bitops": 136068071066002032,
            # 8.0 +=1.5 ->9.5, -=0.25 ->9.25, *=2 ->18.5, //=4 ->4.0 (floored), /=5 ->0.8
            "list_float_ops": 95092501850408,
            # d[3]: 10 +=5 ->15, -=7 ->8, *=4 ->32; s["k"]: 1.5 *=4 ->6.0
            "dict_ops": 15083206,
            # h.f: 7.0 //=2 ->3.0, *=2.5 ->7.5; h.n: 20 %=6 ->2
            "field_scalar_ops": 307502,
            # m[bump_idx(1)] += 7 -> m[1]==27 with one bump
            "index_evaluated_once": 271
        }
    );
    assert not wrong , wrong;
}

# --- str() identity ownership and negative string indexing ---
test "py_str_identity_index: str() keeps temps alive and indices wrap or raise" {
    wrong = wrong_returns(
        "py_str_identity_index.jac",
        {
            # str() of an owned temp keeps the value alive
            "str_of_owned_temp": 2,
            # test-slug shape: ok=1 (slug == "canary_t"), len=8
            "slug_of_desc": 18,
            # v[-1]==v[0], v[-1]=='"', v[-2]=='t', "abc"[-3]=='a'
            "neg_index_reads": 1111,
            # IndexError below and above range
            "neg_index_oob": 1,
            "pos_index_oob": 1
        }
    );
    assert not wrong , wrong;
}
