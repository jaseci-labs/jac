"""Getters and methods of every base dispatch correctly on a class built from two bases in other units."""
import from .joined { Both }
import from .readers { read_left, read_right }

def chk_multi_base_dispatch -> int {
    both = Both(left_seed=2, right_seed=3);
    return read_left(both) * 10000 + read_right(both);
}

with entry {
    print(chk_multi_base_dispatch());
}
