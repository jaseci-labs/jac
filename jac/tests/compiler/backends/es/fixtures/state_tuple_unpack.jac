"""Fixture: every way a component rebinds `has` state: tuple, list, star, nested and
chained assignments, for-loop targets, walrus and augmented operators.
Each write goes through the field's setter, never a bare name the module never declares.
"""

def:pub app -> JsxElement {
    has a: int = 0,
        b: int = 0,
        items: list[int] = [1, 2, 3];

    def swap {
        (a, b) = (b + 1, a + 1);
    }

    def swap_list {
        [a, b] = [b + 2, a + 2];
    }

    def mixed {
        (a, x) = (5, 6);
        b = x;
    }

    def star {
        (a, *rest) = items;
        b = len(rest);
    }

    def nested {
        (a, (b, y)) = (1, (2, 3));
        a = y;
    }

    def chained {
        a = b=7;
    }

    def middle_star {
        (a, *mid, b) = items;
        a = len(mid);
    }

    def loop_tuple {
        for (a, b) in [[1, 2], [3, 4]] {}
    }

    def loop_name {
        for a in [5, 6] {}
    }

    def loop_star {
        for (a, *rest, b) in [[1, 2, 3, 4]] {}
    }

    def walrus {
        if (a := 9) > 0 {
            b = a;
        }
    }

    def aug_ops {
        a = 7;
        a //= 2;
        b = -7;
        b %= 3;
    }

    return
        <div>
            <button onClick={swap}>1</button>
            <button onClick={swap_list}>2</button>
            <button onClick={mixed}>3</button>
            <button onClick={star}>4</button>
            <button onClick={nested}>5</button>
            <button onClick={chained}>6</button>
            <button onClick={middle_star}>7</button>
            <button onClick={loop_tuple}>8</button>
            <button onClick={loop_name}>9</button>
            <button onClick={loop_star}>10</button>
            <button onClick={walrus}>11</button>
            <button onClick={aug_ops}>12</button>
        </div>;
}
