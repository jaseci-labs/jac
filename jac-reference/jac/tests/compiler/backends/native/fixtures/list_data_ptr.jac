"""`__list_data_ptr` on each operand it accepts: a variable, a field and an
element, of an `int` and a `float` list. Each function writes through the
buffer and reads the element back through the list, and the other way."""

obj Regs {
    has r: list[int] = [];
}

def int_roundtrip(x: int) -> int {
    l: list[int] = [1, 2, 3];
    p: int = __list_data_ptr(l);
    __mem_store_i64(p + 16, x);
    return l[2] * 10 + __mem_load_i64(p);
}

def float_roundtrip(x: int) -> int {
    l: list[float] = [0.5, 0.0];
    p: int = __list_data_ptr(l);
    __mem_store_i64(p + 8, __float_bits(float(x) + 0.25));
    return int(l[1] * 4.0) + int(__bits_float(__mem_load_i64(p)) * 2.0);
}

def field_operand(x: int) -> int {
    regs: Regs = Regs(r=[0, 0, 0]);
    __mem_store_i64(__list_data_ptr(regs.r) + 8, x);
    return regs.r[1];
}

def element_operand(x: int) -> int {
    rows: list[list[int]] = [[0, 0], [0, 0]];
    __mem_store_i64(__list_data_ptr(rows[1]), x);
    return rows[1][0] + rows[0][0];
}

"""After the list grew, a fresh call returns the buffer it moved to."""
def after_growth(n: int) -> int {
    l: list[int] = [0];
    i: int = 1;
    while i < n {
        l.append(i * 3);
        i = i + 1;
    }
    return __mem_load_i64(__list_data_ptr(l) + 8 * (n - 1));
}

with entry {
    print(
        int_roundtrip(4),
        float_roundtrip(4),
        field_operand(4),
        element_operand(4),
        after_growth(100)
    );
}
