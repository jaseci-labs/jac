"""Range emitter: constructor, loops, methods (count, index, eq, contains).

Cross-backend equivalence fixture.
"""

# --- Range constructor and methods ---
def range_py() -> dict {
    # range_builtin_py
    r1: list = list(range(5));
    r2: list = list(range(2, 7));
    r3: list = list(range(0, 10, 2));
    r4: list = list(range(10, 0, -2));
    r5: list = list(range(5, 5));
    r6: list = list(range(10, 5));
    r7: list = list(range(3, 4));

    total: int = 0;
    for i in range(5) {
        total += i;
    }

    stepped: list = [];
    for i in range(1, 10, 3) {
        stepped.append(i);
    }

    countdown: list = [];
    for i in range(5, 0, -1) {
        countdown.append(i);
    }

    pairs: list = [];
    for i in range(3) {
        for j in range(2) {
            pairs.append(i * 10 + j);
        }
    }

    # range_methods_py
    r_m: list = list(range(0, 10, 2));
    count_hit: int = r_m.count(4);
    count_miss: int = r_m.count(3);
    idx_first: int = r_m.index(0);
    idx_mid: int = r_m.index(6);
    idx_last: int = r_m.index(8);
    eq_same: bool = list(range(5)) == list(range(5));
    eq_diff_step: bool = list(range(0, 6, 2)) == list(range(0, 6, 2));
    ne_diff: bool = list(range(5)) != list(range(6));
    ne_empty: bool = list(range(0)) != list(range(5));
    contains_yes: bool = 4 in r_m;
    contains_no: bool = 3 in r_m;
    contains_start: bool = 0 in r_m;
    contains_end: bool = 8 in r_m;
    contains_past: bool = 10 in r_m;

    return {
        "r_stop": r1, "r_start_stop": r2,
        "r_step": r3, "r_neg_step": r4,
        "r_empty_eq": r5, "r_empty_inv": r6,
        "r_single": r7,
        "loop_sum": total, "loop_stepped": stepped,
        "loop_countdown": countdown, "loop_nested": pairs,
        "count_hit": count_hit, "count_miss": count_miss,
        "idx_first": idx_first, "idx_mid": idx_mid, "idx_last": idx_last,
        "eq_same": eq_same, "eq_diff_step": eq_diff_step,
        "ne_diff": ne_diff, "ne_empty": ne_empty,
        "contains_yes": contains_yes, "contains_no": contains_no,
        "contains_start": contains_start, "contains_end": contains_end,
        "contains_past": contains_past
    };
}

cl def range_cl() -> dict {
    r1: list = list(range(5));
    r2: list = list(range(2, 7));
    r3: list = list(range(0, 10, 2));
    r4: list = list(range(10, 0, -2));
    r5: list = list(range(5, 5));
    r6: list = list(range(10, 5));
    r7: list = list(range(3, 4));

    total: int = 0;
    for i in range(5) {
        total += i;
    }

    stepped: list = [];
    for i in range(1, 10, 3) {
        stepped.append(i);
    }

    countdown: list = [];
    for i in range(5, 0, -1) {
        countdown.append(i);
    }

    pairs: list = [];
    for i in range(3) {
        for j in range(2) {
            pairs.append(i * 10 + j);
        }
    }

    r_m: list = list(range(0, 10, 2));
    count_hit: int = r_m.count(4);
    count_miss: int = r_m.count(3);
    idx_first: int = r_m.index(0);
    idx_mid: int = r_m.index(6);
    idx_last: int = r_m.index(8);
    eq_same: bool = list(range(5)) == list(range(5));
    eq_diff_step: bool = list(range(0, 6, 2)) == list(range(0, 6, 2));
    ne_diff: bool = list(range(5)) != list(range(6));
    ne_empty: bool = list(range(0)) != list(range(5));
    contains_yes: bool = 4 in r_m;
    contains_no: bool = 3 in r_m;
    contains_start: bool = 0 in r_m;
    contains_end: bool = 8 in r_m;
    contains_past: bool = 10 in r_m;

    return {
        "r_stop": r1, "r_start_stop": r2,
        "r_step": r3, "r_neg_step": r4,
        "r_empty_eq": r5, "r_empty_inv": r6,
        "r_single": r7,
        "loop_sum": total, "loop_stepped": stepped,
        "loop_countdown": countdown, "loop_nested": pairs,
        "count_hit": count_hit, "count_miss": count_miss,
        "idx_first": idx_first, "idx_mid": idx_mid, "idx_last": idx_last,
        "eq_same": eq_same, "eq_diff_step": eq_diff_step,
        "ne_diff": ne_diff, "ne_empty": ne_empty,
        "contains_yes": contains_yes, "contains_no": contains_no,
        "contains_start": contains_start, "contains_end": contains_end,
        "contains_past": contains_past
    };
}

na {
    def range_na() -> dict[str, any] {
        r1_len: int = len(list(range(5)));
        r1_first: int = list(range(5))[0];
        r1_last: int = list(range(5))[4];

        r2_len: int = len(list(range(2, 7)));
        r2_first: int = list(range(2, 7))[0];

        r3_len: int = len(list(range(0, 10, 2)));
        r3_first: int = list(range(0, 10, 2))[0];
        r3_last: int = list(range(0, 10, 2))[4];

        r4_len: int = len(list(range(10, 0, -2)));
        r4_first: int = list(range(10, 0, -2))[0];

        r5_len: int = len(list(range(5, 5)));
        r6_len: int = len(list(range(10, 5)));
        r7_len: int = len(list(range(3, 4)));
        r7_val: int = list(range(3, 4))[0];

        total: int = 0;
        for i in range(5) {
            total += i;
        }

        stepped_sum: int = 0;
        stepped_first: int = 0;
        stepped_count: int = 0;
        for i in range(1, 10, 3) {
            if stepped_count == 0 {
                stepped_first = i;
            }
            stepped_sum += i;
            stepped_count += 1;
        }

        countdown_sum: int = 0;
        countdown_first: int = 0;
        countdown_count: int = 0;
        for i in range(5, 0, -1) {
            if countdown_count == 0 {
                countdown_first = i;
            }
            countdown_sum += i;
            countdown_count += 1;
        }

        nested_sum: int = 0;
        nested_count: int = 0;
        for i in range(3) {
            for j in range(2) {
                nested_sum += i * 10 + j;
                nested_count += 1;
            }
        }

        r_obj = range(0, 10, 2);
        count_hit: int = r_obj.count(4);
        count_miss: int = r_obj.count(3);
        idx_first: int = r_obj.index(0);
        idx_mid: int = r_obj.index(6);
        idx_last: int = r_obj.index(8);

        eq_same: int = range(0, 5, 1) == range(0, 5, 1);
        eq_diff_step: int = range(0, 6, 2) == range(0, 6, 2);
        ne_diff: int = range(0, 5, 1) != range(0, 6, 1);

        contains_yes: int = 4 in r_obj;
        contains_no: int = 3 in r_obj;
        contains_start: int = 0 in r_obj;
        contains_end: int = 8 in r_obj;
        contains_past: int = 10 in r_obj;


        return {
            "r_stop_len": r1_len,
            "r_stop_first": r1_first,
            "r_stop_last": r1_last,
            "r_start_stop_len": r2_len,
            "r_start_stop_first": r2_first,
            "r_step_len": r3_len,
            "r_step_first": r3_first,
            "r_step_last": r3_last,
            "r_neg_step_len": r4_len,
            "r_neg_step_first": r4_first,
            "r_empty_eq_len": r5_len,
            "r_empty_inv_len": r6_len,
            "r_single_len": r7_len,
            "r_single_val": r7_val,
            "loop_sum": total,
            "stepped_sum": stepped_sum,
            "stepped_first": stepped_first,
            "stepped_count": stepped_count,
            "countdown_sum": countdown_sum,
            "countdown_first": countdown_first,
            "countdown_count": countdown_count,
            "nested_sum": nested_sum,
            "nested_count": nested_count,
            "count_hit": count_hit,
            "count_miss": count_miss,
            "idx_first": idx_first,
            "idx_mid": idx_mid,
            "idx_last": idx_last,
            "eq_same": eq_same,
            "eq_diff_step": eq_diff_step,
            "ne_diff": ne_diff,
            "contains_yes": contains_yes,
            "contains_no": contains_no,
            "contains_start": contains_start,
            "contains_end": contains_end,
            "contains_past": contains_past
        };
    }
}
