"""Lists whose elements are variadic tuples (`list[tuple[T, ...]]`).

`tuple[T, ...]` lowers to the sequence `list[T]` does, and every read out of
such a list views its slot through that sequence. The tuple displays stored
into the list used to go in as fixed-arity tuple boxes, so `xs[1][1]` walked a
tuple struct as a list header and crashed. Each function answers whether the
list reads back what Python would see."""

def:pub displayed -> bool {
    xs: list[tuple[float, ...]] = [(3.5, ), (1.5, 2.0)];
    return len(xs) == 2 and len(xs[0]) == 1 and xs[0][0] == 3.5 and xs[1][1] == 2.0;
}

def:pub appended -> bool {
    xs: list[tuple[float, ...]] = [];
    for i in range(4) {
        v = float(i);
        if i % 2 == 0 {
            xs.append((v, ));
        } else {
            xs.append((v, v * 2.0));
        }
    }
    total = 0.0;
    for t in xs {
        for e in t {
            total += e;
        }
    }
    return total == 14.0 and len(xs[2]) == 1 and xs[3][1] == 6.0;
}

def:pub inserted_and_assigned -> bool {
    xs: list[tuple[float, ...]] = [(1.0, )];
    xs.insert(0, (4.0, 5.0, 6.0));
    xs[1] = (7.0, 8.0);
    return len(xs) == 2 and xs[0][2] == 6.0 and len(xs[1]) == 2 and xs[1][1] == 8.0;
}

def:pub int_elements -> bool {
    xs: list[tuple[int, ...]] = [(3, 1), (1, 2, 3)];
    xs.append((0, ));
    return xs[1][2] == 3 and len(xs[2]) == 1 and sum(xs[0]) == 4;
}

def:pub sorted_float_elements -> bool {
    xs: list[tuple[float, ...]] = [(3.5, ), (1.5, 2.0), (2.5, ), (1.5, )];
    ys = sorted(xs);
    return len(ys[0]) == 1
        and ys[0][0] == 1.5
        and len(ys[1]) == 2
        and ys[1][1] == 2.0
        and ys[2][0] == 2.5
        and ys[3][0] == 3.5;
}

def:pub sorted_in_place_reversed -> bool {
    xs: list[tuple[float, ...]] = [(3.5, ), (1.5, 2.0), (2.5, ), (1.5, )];
    xs.sort(reverse=True);
    return xs[0][0] == 3.5 and len(xs[2]) == 2 and len(xs[3]) == 1 and xs[3][0] == 1.5;
}

def:pub sorted_int_elements -> bool {
    xs: list[tuple[int, ...]] = [(3, 1), (1, 2, 3), (1, 2)];
    xs.append((0, ));
    ys = sorted(xs);
    return len(ys[0]) == 1 and len(ys[1]) == 2 and ys[2][2] == 3 and ys[3][0] == 3;
}

"""The fixed-arity form QuakePassion's collision BVH uses stays a tuple."""
def:pub fixed_pairs_median_split -> bool {
    values = [5.5, -2.0, 9.25, 0.0, 3.5, -7.75];
    ranked: list[tuple[float, int]] = [];
    for i in range(len(values)) {
        ranked.append((values[i], i));
    }
    ranked = sorted(ranked);
    middle = len(ranked) // 2;
    left = [pair[1] for pair in ranked[:middle]];
    right = [pair[1] for pair in ranked[middle:]];
    return left == [5, 1, 3] and right == [4, 0, 2] and ranked[0][1] == 5;
}
