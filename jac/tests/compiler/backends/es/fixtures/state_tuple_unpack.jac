"""Fixture: tuple, list, star, nested and chained assignments that write `has` state.
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
        a = b = 7;
    }

    return
        <div>
            <span>{a}</span>
            <span>{b}</span>
            <button
                onClick={lambda {
                    swap();
                    swap_list();
                    mixed();
                    star();
                    nested();
                    chained();
                }}
            >
                go
            </button>
        </div>;
}
