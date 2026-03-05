import from na_struct_export { Point, make_point }

def local_get_x(p: Point) -> int {
    return p.x;
}

def local_sum(p: Point) -> int {
    return p.x + p.y;
}

with entry {
    pt: Point = make_point(3, 4);
    x_val: int = local_get_x(pt);
    print("x =", x_val);
}
