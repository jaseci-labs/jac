"""Getters and methods of every base dispatch correctly on a class built from two bases in other units."""
import from .joined { Both, BothNode }
import from .readers { read_left, read_right, read_left_node, read_right_node }

def chk_multi_base_dispatch -> int {
    both = Both(left_seed=2, right_seed=3);
    return read_left(both) * 10000 + read_right(both);
}

def chk_multi_base_node_dispatch -> int {
    both = BothNode(left_seed=2, right_seed=3, right_items=[1, 2]);
    return read_left_node(both) * 10000 + read_right_node(both);
}

with entry {
    print(chk_multi_base_dispatch());
    print(chk_multi_base_node_dispatch());
}
