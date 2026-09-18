import from typing { Final }
import from checker_final_source { SHARED_RATE }

glob SHARED_RATE = 3.0;  # <-- Error

glob LIMIT: Final[int] = 5;

obj Point {
    has x: Final[int];
    has label: Final[str] = "p";
    has tag: Final[str] postinit;

    def init(x: int) {
        self.x = x;
    }

    def postinit {
        self.tag = "p";
    }

    def move(x: int) {
        self.x = x;  # <-- Error
    }
}

obj Heir(Point) {
    def init {
        super.init(1);
        self.x = 2;  # <-- Error
    }
}

class Meter {
    has ticks: Final[int];

    def __init__(me: Meter, n: int) {
        me.ticks = n;
    }
}

def rebind(items: list[int]) -> int {
    y: Final[int] = 1;
    b: Final = 2;
    y += b;  # <-- Error
    def shadow(xs: list[int]) {
        for y in xs {
            print(y);
        }
    }
    shadow(items);
    for y in items {  # <-- Error
        print(y);
    }
    return y;
}

with entry {
    p = Point(1);
    p.label = "q";  # <-- Error
    match p.x {
        case LIMIT:  # <-- Error
            print(LIMIT);

    }
}
