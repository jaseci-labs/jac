import from .base_a { Left, LeftNode }
import from .base_b { Right, RightNode }

def read_left(seen: Left) -> int {
    return seen.left_value + seen.left_name() + seen.left_extra();
}

def read_right(seen: Right) -> int {
    return seen.right_value + seen.right_name();
}

def read_left_node(seen: LeftNode) -> int {
    return seen.left_value + seen.left_name();
}

def read_right_node(seen: RightNode) -> int {
    return seen.right_value + seen.right_name();
}
