"""Walker-engine acceptance kernel (#7870 item 5): build an owned
region graph, traverse it with a walker, discard -- rc-free in the
enforced build, identical digest across modes."""

import sys;

node Cell {
    has val: int = 0;
}

edge Step {}

walker Summer {
    has acc: int = 0;

    can add with Cell entry {
        self.acc = (self.acc * 31 + here.val) % 1000000007;
        visit [-->];
    }
}

def run(n: int) -> int {
    r: own Region = Region();
    total = 0;
    in r {
        first = Cell(val=1);
        prev = first;
        for i in range(n) {
            nxt = Cell(val=(i * 7 + 3) % 97);
            prev +>:Step:+> nxt;
            prev = nxt;
        }
        w = Summer();
        w spawn first;
        total = w.acc;
    }
    return total;
}

glob n = 200;

with entry {
    print(run(n));
}
