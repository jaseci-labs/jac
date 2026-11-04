import from .base_a { Left }
import from .base_b { Right }

def read_left(seen: Left) -> int {
    return seen.left_value + seen.left_name() + seen.left_extra();
}

def read_right(seen: Right) -> int {
    return seen.right_value + seen.right_name();
}
