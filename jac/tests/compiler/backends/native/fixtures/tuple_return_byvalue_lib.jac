"""The imported half of tuple_return_byvalue.jac: a scalar tuple crossing a
module boundary, as a free function and as a method."""

def split_ratio(n: int) -> tuple[int, f64] {
    return (n // 2, n / 4.0);
}

obj Extent {
    has w: int = 3,
        h: int = 4;

    def dims -> tuple[int, int] {
        return (self.w, self.h);
    }
}
