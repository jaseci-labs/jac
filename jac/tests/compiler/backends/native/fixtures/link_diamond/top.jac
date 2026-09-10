import from left { left_value }
import from right { right_value }
import from extra { extra_value }
import from base { Point }

def total(p: Point) -> int {
    return left_value(p) + right_value(p) + extra_value(p);
}

with entry {
    p = Point(x=3, y=4);
    print(total(p));
}
