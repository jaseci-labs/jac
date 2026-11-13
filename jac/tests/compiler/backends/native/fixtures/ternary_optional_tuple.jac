"""Conditional expressions whose sides are a tuple literal and `None`, kept in
lists of optional tuples: appended, stored by index, returned, and read back."""

obj Point {
    has x: float = 0.0;
}

def collect(count: int) -> list[tuple[Point, Point] | None] {
    items: list[tuple[Point, Point] | None] = [];
    for k in range(count) {
        items.append(
            (Point(x=float(k)), Point(x=float(k * 2))) if k % 3 != 0 else None
        );
    }
    return items;
}

def relabel(count: int) -> list[tuple[str, int] | None] {
    items: list[tuple[str, int] | None] = [];
    for k in range(count) {
        items.append(("", 0));
    }
    for k in range(count) {
        items[k] = None if k % 2 == 0 else ("w" * (k % 5), k);
    }
    return items;
}

def pick(k: int) -> tuple[Point, float] | None {
    return (Point(x=float(k)), 0.5) if k > 0 else None;
}

with entry {
    items = collect(1000);
    present = 0;
    total = 0.0;
    for item in items {
        if item is not None {
            present += 1;
            total += item[0].x + item[1].x;
        }
    }
    print(present, total);
    first = items[0];
    second = items[1];
    if first is None and second is not None {
        print(second[0].x, second[1].x);
    }
    words = relabel(10);
    nones = 0;
    letters = 0;
    for word in words {
        if word is None {
            nones += 1;
        } else {
            letters += len(word[0]) + word[1];
        }
    }
    print(nones, letters);
    none_pick = pick(0);
    some_pick = pick(4);
    print(none_pick is None);
    if some_pick is not None {
        print(some_pick[0].x, some_pick[1]);
    }
}
