import from base { Point, scale }

def left_value(p: Point) -> int {
    return scale(p.sum(), 2);
}
